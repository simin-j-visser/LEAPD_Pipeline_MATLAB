function rhos = evaluate_correlation_leapd_fast( ...
    targetFeatures, referenceFeatures, targetValues, ...
    foldCache, maxDimension, useNormalizedProjection)
%EVALUATE_CORRELATION_LEAPD_FAST Fast OOF correlation search.
%
% Evaluates PCA dimensions 1:maxDimension while reusing each SVD:
%   - the reference-group SVD is computed once;
%   - the target-group SVD is computed once per CV fold;
%   - all PCA dimensions reuse progressively larger subsets of those bases.
%
% foldCache.train{fold} and foldCache.test{fold} define the target/group-1
% cross-validation split. LOOCV is simply the special case in which every
% test fold contains one target subject.
%
% LEAPD convention:
%   score = distance-to-reference / ...
%           (distance-to-target + distance-to-reference)
%   higher score = more target/group-1-like.
%
% Output:
%   rhos(d) = Spearman rho from all out-of-fold target scores at PCA
%             dimension d.

    targetFeatures = double(targetFeatures);
    referenceFeatures = double(referenceFeatures);
    targetValues = double(targetValues(:));

    nTarget = size(targetFeatures,1);
    nFeatures = size(targetFeatures,2);
    nFolds = numel(foldCache.train);

    if numel(targetValues) ~= nTarget
        error('Target feature and target-value counts do not match.');
    end

    minimumTrainingTargetSize = inf;
    for fold = 1:nFolds
        minimumTrainingTargetSize = min( ...
            minimumTrainingTargetSize, ...
            sum(foldCache.train{fold}));
    end

    maximumAllowed = min([ ...
        nFeatures, ...
        minimumTrainingTargetSize - 1, ...
        size(referenceFeatures,1) - 1]);

    if maxDimension < 1 || maxDimension > maximumAllowed
        error('Invalid maximum PCA dimension: %d.', maxDimension);
    end

    %% Reference hyperplane SVD ONCE
    referenceMean = mean(referenceFeatures, 1);
    centeredReference = referenceFeatures - referenceMean;
    [~,~,referenceV] = svd(centeredReference, 'econ');
    referenceV = referenceV(:,1:maxDimension);

    leapdIndices = nan(nTarget, maxDimension);
    assigned = false(nTarget,1);

    %% One target SVD per CV fold
    for fold = 1:nFolds
        trainMask = foldCache.train{fold};
        testMask = foldCache.test{fold};

        targetTraining = targetFeatures(trainMask,:);
        targetMean = mean(targetTraining, 1);
        centeredTargetTraining = targetTraining - targetMean;
        [~,~,targetV] = svd(centeredTargetTraining, 'econ');
        targetV = targetV(:,1:maxDimension);

        testFeatures = targetFeatures(testMask,:);
        testRows = find(testMask);
        assigned(testRows) = true;

        centeredToTarget = testFeatures - targetMean;
        centeredToReference = testFeatures - referenceMean;

        for pcaDimension = 1:maxDimension
            targetBasis = targetV(:,1:pcaDimension);
            referenceBasis = referenceV(:,1:pcaDimension);

            distanceToTarget = batch_distance_from_centered( ...
                centeredToTarget, targetBasis, ...
                useNormalizedProjection);

            distanceToReference = batch_distance_from_centered( ...
                centeredToReference, referenceBasis, ...
                useNormalizedProjection);

            denominator = distanceToTarget + distanceToReference;
            valid = denominator > eps;

            scores = nan(size(denominator));
            scores(valid) = ...
                distanceToReference(valid) ./ denominator(valid);

            leapdIndices(testRows,pcaDimension) = scores;
        end
    end

    if any(~assigned)
        error('Some target subjects were not assigned to a CV test fold.');
    end

    %% Spearman rho from the COMPLETE OOF score vector for each dimension
    rhos = nan(maxDimension,1);

    for pcaDimension = 1:maxDimension
        scores = leapdIndices(:,pcaDimension);
        valid = isfinite(scores) & isfinite(targetValues);

        if sum(valid) >= 3
            rhos(pcaDimension) = corr( ...
                scores(valid), ...
                targetValues(valid), ...
                'Type', 'Spearman');
        end
    end
end


function distances = batch_distance_from_centered( ...
    centeredFeatures, basis, useNormalizedProjection)

    if useNormalizedProjection
        numerator = sqrt(sum((centeredFeatures * basis).^2, 2));
        denominator = sqrt(sum(centeredFeatures.^2, 2));

        distances = zeros(size(numerator));
        valid = denominator ~= 0;
        distances(valid) = numerator(valid) ./ denominator(valid);
    else
        residual = centeredFeatures - ...
            (centeredFeatures * basis) * basis';
        distances = sqrt(sum(residual.^2, 2));
    end
end
