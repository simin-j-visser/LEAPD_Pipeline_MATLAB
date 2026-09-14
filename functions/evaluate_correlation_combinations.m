function [combinationResults, bestBySize, bestScoreTable] = ...
    evaluate_correlation_combinations( ...
        channelIndices, ...
        targetValues, ...
        subjectIDs, ...
        channelNames, ...
        minimumCombinationSize, ...
        maximumCombinationSize, ...
        selectionCriterion, ...
        topKPerSize, ...
        batchSize, ...
        useParallel)
%EVALUATE_CORRELATION_COMBINATIONS Evaluate multi-channel LEAPD combinations.
%
% All requested channel combinations are evaluated exactly, but only the
% top K results within each model size are retained in memory and returned.
% This avoids constructing or storing very large nchoosek matrices.
%
% Multi-channel indices are formed using the geometric mean of odds.
% Combinations are ranked independently within each requested model size.

    targetValues = targetValues(:);
    subjectIDs = string(subjectIDs(:));
    channelNames = string(channelNames(:));

    nSubjects = size(channelIndices,1);
    nChannels = size(channelIndices,2);

    if numel(targetValues) ~= nSubjects || numel(subjectIDs) ~= nSubjects
        error('Subject counts do not match the channel-index matrix.');
    end

    if numel(channelNames) ~= nChannels
        error('Channel-name count does not match the index matrix.');
    end

    if minimumCombinationSize < 1 || ...
            maximumCombinationSize < minimumCombinationSize
        error('Invalid channel-combination size range.');
    end

    if maximumCombinationSize > nChannels
        error(['maximumCombinationSize (%d) exceeds the number of ', ...
               'available channels (%d).'], ...
            maximumCombinationSize, nChannels);
    end

    if isempty(topKPerSize) || ~isfinite(topKPerSize) || topKPerSize < 1
        error('topKPerSize must be a finite positive integer.');
    end

    topKPerSize = floor(topKPerSize);

    if isempty(batchSize) || ~isfinite(batchSize) || batchSize < 1
        error('batchSize must be a finite positive integer.');
    end

    batchSize = floor(batchSize);

    combinationResults = table();
    bestBySize = table();
    bestScoreTable = table();

    for modelSize = ...
            minimumCombinationSize:maximumCombinationSize

        totalCombinations = nchoosek(nChannels, modelSize);

        fprintf('\nEvaluating %d-channel combinations: %.0f total\n', ...
            modelSize, totalCombinations);

        currentTop = table();

        currentCombination = 1:modelSize;
        hasCurrent = true;
        processed = 0;

        while hasCurrent
            [batch, currentCombination, hasCurrent] = ...
                next_combination_batch( ...
                    nChannels, ...
                    modelSize, ...
                    currentCombination, ...
                    hasCurrent, ...
                    batchSize);

            nBatch = size(batch,1);
            rows = cell(nBatch,1);

            if useParallel
                parfor i = 1:nBatch
                    rows{i} = evaluate_one_combination( ...
                        batch(i,:), ...
                        channelIndices, ...
                        targetValues, ...
                        channelNames, ...
                        modelSize);
                end
            else
                for i = 1:nBatch
                    rows{i} = evaluate_one_combination( ...
                        batch(i,:), ...
                        channelIndices, ...
                        targetValues, ...
                        channelNames, ...
                        modelSize);
                end
            end

            rows = rows(~cellfun('isempty', rows));

            if ~isempty(rows)
                batchTable = vertcat(rows{:});

                if isempty(currentTop)
                    currentTop = batchTable;
                else
                    currentTop = [currentTop; batchTable]; %#ok<AGROW>
                end

                currentTop = sort_correlation_results( ...
                    currentTop, selectionCriterion);

                if height(currentTop) > topKPerSize
                    currentTop = currentTop(1:topKPerSize,:);
                end
            end

            processed = processed + nBatch;

            fprintf('  %d-channel progress: %.0f / %.0f (%.1f%%)\n', ...
                modelSize, ...
                processed, ...
                totalCombinations, ...
                100 * processed / totalCombinations);
        end

        if isempty(currentTop)
            warning('No valid %d-channel combinations.', modelSize);
            continue;
        end

        combinationResults = [ ...
            combinationResults; currentTop]; %#ok<AGROW>

        bestRow = currentTop(1,:);
        bestBySize = [bestBySize; bestRow]; %#ok<AGROW>

        bestNames = split(bestRow.Channels(1), ',');
        bestIndices = zeros(numel(bestNames),1);

        for j = 1:numel(bestNames)
            idx = find(strcmpi(channelNames, strtrim(bestNames(j))), 1);

            if isempty(idx)
                error('Could not recover channel "%s".', bestNames(j));
            end

            bestIndices(j) = idx;
        end

        bestCombinedIndex = combine_channel_indices( ...
            channelIndices(:,bestIndices));

        bestChannels = bestRow.Channels(1);
        bestRho = bestRow.SpearmanRho(1);
        bestP = bestRow.PValue(1);

        scoreRows = table( ...
            repmat(modelSize, nSubjects, 1), ...
            repmat(bestChannels, nSubjects, 1), ...
            subjectIDs, ...
            targetValues, ...
            bestCombinedIndex, ...
            repmat(bestRho, nSubjects, 1), ...
            repmat(bestP, nSubjects, 1), ...
            'VariableNames', { ...
                'NumberOfChannels', ...
                'Channels', ...
                'SubjectID', ...
                'Target', ...
                'CombinedLEAPDIndex', ...
                'SpearmanRho', ...
                'PValue'});

        bestScoreTable = [ ...
            bestScoreTable; scoreRows]; %#ok<AGROW>
    end

    if isempty(combinationResults)
        error('No valid channel combinations were evaluated.');
    end
end


function row = evaluate_one_combination( ...
    indices, channelIndices, targetValues, channelNames, modelSize)

    selectedIndices = channelIndices(:,indices);

    if any(all(~isfinite(selectedIndices),1))
        row = [];
        return;
    end

    combinedIndex = combine_channel_indices(selectedIndices);

    valid = isfinite(combinedIndex) & isfinite(targetValues);
    nValid = sum(valid);

    if nValid < 3
        row = [];
        return;
    end

    [rho,pValue] = corr( ...
        combinedIndex(valid), ...
        targetValues(valid), ...
        'Type', 'Spearman');

    if ~isfinite(rho)
        row = [];
        return;
    end

    channelText = strjoin(channelNames(indices), ',');

    row = table( ...
        modelSize, ...
        channelText, ...
        rho, ...
        pValue, ...
        nValid, ...
        'VariableNames', { ...
            'NumberOfChannels', ...
            'Channels', ...
            'SpearmanRho', ...
            'PValue', ...
            'NValid'});
end


function [batch, nextCombination, hasNext] = ...
    next_combination_batch( ...
        nChannels, modelSize, currentCombination, ...
        hasCurrent, batchSize)

    batch = zeros(batchSize, modelSize);
    count = 0;

    combination = currentCombination;
    hasCombination = hasCurrent;

    while hasCombination && count < batchSize
        count = count + 1;
        batch(count,:) = combination;

        [combination, hasCombination] = ...
            advance_combination( ...
                combination, nChannels, modelSize);
    end

    batch = batch(1:count,:);
    nextCombination = combination;
    hasNext = hasCombination;
end


function [combination, hasNext] = ...
    advance_combination(combination, nChannels, modelSize)

    position = modelSize;

    while position >= 1 && ...
            combination(position) == nChannels - modelSize + position

        position = position - 1;
    end

    if position == 0
        hasNext = false;
        return;
    end

    combination(position) = combination(position) + 1;

    for j = position+1:modelSize
        combination(j) = combination(j-1) + 1;
    end

    hasNext = true;
end


function results = sort_correlation_results( ...
    results, selectionCriterion)

    switch lower(selectionCriterion)
        case 'min'
            results = sortrows( ...
                results, 'SpearmanRho', 'ascend');

        case 'max'
            results = sortrows( ...
                results, 'SpearmanRho', 'descend');

        case 'maxabs'
            [~,order] = sort( ...
                abs(results.SpearmanRho), 'descend');
            results = results(order,:);

        otherwise
            error('Unknown selection criterion: "%s".', ...
                selectionCriterion);
    end
end
