function accuracies = cross_validate_binary_leapd_fast( ...
    features, classes, foldCache, maxDimension, ...
    useNormalizedProjection)
%CROSS_VALIDATE_BINARY_LEAPD_FAST Fast binary LEAPD CV for search.
%
% PCA dimensions 1:maxDimension are evaluated in one CV pass. For each
% fold, the class-1 and class-0 SVDs are each computed only once.
%
% LEAPD convention used throughout this pipeline:
%   score = distance-to-class-0 / (distance1 + distance0)
%   higher score = more class-1-like
%   score > 0.5 predicts class 1
%
% Output:
%   accuracies(d) = cross-validated accuracy (%) for dimension d.

    features = double(features);
    classes = classes(:);

    nSubjects = size(features,1);
    nFeatures = size(features,2);
    nFolds = numel(foldCache.train);

    if nSubjects ~= numel(classes)
        error('Number of subjects and class labels does not match.');
    end

    if maxDimension < 1
        error('maxDimension must be at least 1.');
    end

    correctCounts = zeros(maxDimension,1);
    totalPredictions = 0;

    for fold = 1:nFolds
        trainIndex = foldCache.train{fold};
        testIndex = foldCache.test{fold};

        XTrain = features(trainIndex,:);
        yTrain = classes(trainIndex);
        XTest = features(testIndex,:);
        yTest = classes(testIndex);

        class1 = XTrain(yTrain == 1,:);
        class0 = XTrain(yTrain == 0,:);

        if isempty(class1) || isempty(class0)
            error('Both classes must be present in the training data.');
        end

        foldMaximumDimension = min([ ...
            nFeatures, ...
            size(class1,1)-1, ...
            size(class0,1)-1]);

        if maxDimension > foldMaximumDimension
            error([ ...
                'Requested PCA dimension %d is invalid in fold %d; ' ...
                'maximum available dimension is %d.'], ...
                maxDimension, fold, foldMaximumDimension);
        end

        %% Fit each class subspace ONCE for this fold
        mean1 = mean(class1, 1);
        centeredTrain1 = class1 - mean1;
        [~,~,V1] = svd(centeredTrain1, 'econ');

        mean0 = mean(class0, 1);
        centeredTrain0 = class0 - mean0;
        [~,~,V0] = svd(centeredTrain0, 'econ');

        V1 = V1(:,1:maxDimension);
        V0 = V0(:,1:maxDimension);

        centeredTest1 = XTest - mean1;
        centeredTest0 = XTest - mean0;

        %% Reuse those SVDs for every PCA dimension
        for pcaDimension = 1:maxDimension
            basis1 = V1(:,1:pcaDimension);
            basis0 = V0(:,1:pcaDimension);

            if useNormalizedProjection
                projection1 = centeredTest1 * basis1;
                projection0 = centeredTest0 * basis0;

                numerator1 = sqrt(sum(projection1.^2, 2));
                numerator0 = sqrt(sum(projection0.^2, 2));

                denominator1 = sqrt(sum(centeredTest1.^2, 2));
                denominator0 = sqrt(sum(centeredTest0.^2, 2));

                distance1 = zeros(size(numerator1));
                distance0 = zeros(size(numerator0));

                valid1 = denominator1 ~= 0;
                valid0 = denominator0 ~= 0;

                distance1(valid1) = ...
                    numerator1(valid1) ./ denominator1(valid1);
                distance0(valid0) = ...
                    numerator0(valid0) ./ denominator0(valid0);
            else
                residual1 = centeredTest1 - ...
                    (centeredTest1 * basis1) * basis1';

                residual0 = centeredTest0 - ...
                    (centeredTest0 * basis0) * basis0';

                distance1 = sqrt(sum(residual1.^2, 2));
                distance0 = sqrt(sum(residual0.^2, 2));
            end

            denominator = distance1 + distance0;
            denominator(denominator == 0) = eps;
            scores = distance0 ./ denominator;
            predictions = double(scores > 0.5);

            correctCounts(pcaDimension) = ...
                correctCounts(pcaDimension) + ...
                sum(predictions == yTest);
        end

        totalPredictions = totalPredictions + numel(yTest);
    end

    if totalPredictions ~= nSubjects
        error([ ...
            'Cross-validation produced %d predictions for %d subjects.'], ...
            totalPredictions, nSubjects);
    end

    accuracies = 100 * correctCounts / totalPredictions;
end
