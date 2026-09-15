function accuracies = cross_validate_binary_leapd_fast( ...
    features, classes, foldCache, maxDimension, ...
    useNormalizedProjection)
%CROSS_VALIDATE_BINARY_LEAPD_FAST Fast binary LEAPD CV for search.
%
% Vectorized version:
%   - SVD is computed once per class per fold.
%   - Projection onto all PCA dimensions is computed once.
%   - Distances for dimensions 1:maxDimension are obtained using
%     cumulative projection energy.
%
% LEAPD convention:
%   score = distance-to-class-0 / (distance1 + distance0)
%   higher score = more class-1-like
%   score > 0.5 predicts class 1

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

    if maxDimension > nFeatures
        error('maxDimension cannot exceed the number of features.');
    end

    correctCounts = zeros(maxDimension,1);
    totalPredictions = 0;

    for fold = 1:nFolds

        trainIndex = foldCache.train{fold};
        testIndex  = foldCache.test{fold};

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

        mean1 = mean(class1, 1);
        centeredTrain1 = class1 - mean1;
        [~,~,V1] = svd(centeredTrain1, 'econ');
        V1 = V1(:,1:maxDimension);

        mean0 = mean(class0, 1);
        centeredTrain0 = class0 - mean0;
        [~,~,V0] = svd(centeredTrain0, 'econ');
        V0 = V0(:,1:maxDimension);

        centeredTest1 = XTest - mean1;
        centeredTest0 = XTest - mean0;

        projection1 = centeredTest1 * V1;
        projection0 = centeredTest0 * V0;

        cumulativeProjectionEnergy1 = cumsum(projection1.^2, 2);
        cumulativeProjectionEnergy0 = cumsum(projection0.^2, 2);

        if useNormalizedProjection

            denominator1 = sqrt(sum(centeredTest1.^2, 2));
            denominator0 = sqrt(sum(centeredTest0.^2, 2));

            distance1 = zeros(size(cumulativeProjectionEnergy1));
            distance0 = zeros(size(cumulativeProjectionEnergy0));

            valid1 = denominator1 ~= 0;
            valid0 = denominator0 ~= 0;

            distance1(valid1,:) = ...
                sqrt(cumulativeProjectionEnergy1(valid1,:)) ./ ...
                denominator1(valid1);

            distance0(valid0,:) = ...
                sqrt(cumulativeProjectionEnergy0(valid0,:)) ./ ...
                denominator0(valid0);

        else

            totalEnergy1 = sum(centeredTest1.^2, 2);
            totalEnergy0 = sum(centeredTest0.^2, 2);

            residualEnergy1 = ...
                totalEnergy1 - cumulativeProjectionEnergy1;

            residualEnergy0 = ...
                totalEnergy0 - cumulativeProjectionEnergy0;

            residualEnergy1 = max(residualEnergy1, 0);
            residualEnergy0 = max(residualEnergy0, 0);

            distance1 = sqrt(residualEnergy1);
            distance0 = sqrt(residualEnergy0);
        end

        denominator = distance1 + distance0;
        denominator(denominator == 0) = eps;

        scores = distance0 ./ denominator;
        predictions = double(scores > 0.5);

        correctCounts = correctCounts + ...
            sum(predictions == yTest, 1)';

        totalPredictions = totalPredictions + numel(yTest);
    end

    if totalPredictions ~= nSubjects
        error([ ...
            'Cross-validation produced %d predictions for %d subjects.'], ...
            totalPredictions, nSubjects);
    end

    accuracies = 100 * correctCounts / totalPredictions;
end
