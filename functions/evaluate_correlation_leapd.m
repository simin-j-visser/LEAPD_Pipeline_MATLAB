function result = evaluate_correlation_leapd( ...
    targetFeatures, referenceFeatures, targetValues, ...
    cvPartition, pcaDimension, useNormalizedProjection)
%EVALUATE_CORRELATION_LEAPD Out-of-fold target-group LEAPD correlation.
%
% The target/group-1 subjects are partitioned according to cvPartition.
% For each fold, the target hyperplane is fit only on target training
% subjects and scores are produced only for held-out target subjects.
%
% The reference/group-0 hyperplane uses all reference subjects in every
% fold because reference subjects are not the clinical-target subjects
% being cross-validated.
%
% If cvPartition is leave-one-out, the returned scores are LOOCV scores.
% If cvPartition is K-fold, the returned scores are K-fold OOF scores.
%
% Unified LEAPD convention:
%   score = distance-to-reference / ...
%           (distance-to-target + distance-to-reference)
%   higher score = more target/group-1-like.

    if nargin < 6
        useNormalizedProjection = false;
    end

    targetFeatures = double(targetFeatures);
    referenceFeatures = double(referenceFeatures);

    nTarget = size(targetFeatures,1);

    if ~isempty(targetValues) && numel(targetValues) ~= nTarget
        error('Target feature and target-value counts do not match.');
    end

    partitionSize = numel(training(cvPartition, 1));
    if partitionSize ~= nTarget
        error(['Correlation CV partition contains %d observations, ', ...
               'but targetFeatures contains %d subjects.'], ...
            partitionSize, nTarget);
    end

    [referenceBasis, referenceMean] = ...
        get_hyperplane_basis(referenceFeatures, pcaDimension);

    leapdIndices = nan(nTarget,1);
    assigned = false(nTarget,1);

    for fold = 1:cvPartition.NumTestSets
        trainMask = training(cvPartition, fold);
        testMask = test(cvPartition, fold);

        targetTraining = targetFeatures(trainMask,:);

        if size(targetTraining,1) <= pcaDimension
            error([ ...
                'PCA dimension %d is invalid in correlation fold %d; ', ...
                'only %d target training subjects are available.'], ...
                pcaDimension, fold, size(targetTraining,1));
        end

        [targetBasis, targetMean] = ...
            get_hyperplane_basis(targetTraining, pcaDimension);

        testFeatures = targetFeatures(testMask,:);
        testRows = find(testMask);
        assigned(testRows) = true;

        for j = 1:size(testFeatures,1)
            x = testFeatures(j,:);

            distanceToTarget = distance_to_hyperplane( ...
                x, targetBasis, targetMean, ...
                useNormalizedProjection);

            distanceToReference = distance_to_hyperplane( ...
                x, referenceBasis, referenceMean, ...
                useNormalizedProjection);

            denominator = distanceToTarget + distanceToReference;

            if denominator > eps
                leapdIndices(testRows(j)) = ...
                    distanceToReference / denominator;
            end
        end
    end

    if any(~assigned)
        error('Some target subjects were not assigned to a CV test fold.');
    end

    result = struct();
    result.LEAPDIndices = leapdIndices;
    result.Rho = NaN;
    result.PValue = NaN;

    if ~isempty(targetValues)
        targetValues = targetValues(:);
        valid = isfinite(leapdIndices) & isfinite(targetValues);

        if sum(valid) >= 3
            [result.Rho, result.PValue] = corr( ...
                leapdIndices(valid), ...
                targetValues(valid), ...
                'Type', 'Spearman');
        end
    end
end
