function [combinationResults, bestBySize, bestScoreTable] = ...
    evaluate_binary_combinations( ...
        channelIndices, ...
        classes, ...
        subjectIDs, ...
        channelNames, ...
        minimumCombinationSize, ...
        maximumCombinationSize, ...
        topKPerSize, ...
        batchSize, ...
        useParallel)
%EVALUATE_BINARY_COMBINATIONS Evaluate all requested channel combinations.
%
% All combinations are evaluated exactly. Only the top K within each model
% size are retained in memory and returned.

    classes = classes(:);
    subjectIDs = string(subjectIDs(:));
    channelNames = string(channelNames(:));

    [nSubjects, nChannels] = size(channelIndices);

    if numel(classes) ~= nSubjects || numel(subjectIDs) ~= nSubjects
        error('Subject counts do not match the channel-index matrix.');
    end

    if numel(channelNames) ~= nChannels
        error('Channel-name count does not match the index matrix.');
    end

    validate_combination_settings( ...
        nChannels, minimumCombinationSize, ...
        maximumCombinationSize, topKPerSize, batchSize);

    topKPerSize = floor(topKPerSize);
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
                    nChannels, modelSize, ...
                    currentCombination, hasCurrent, batchSize);

            nBatch = size(batch,1);
            rows = cell(nBatch,1);

            if useParallel
                parfor i = 1:nBatch
                    rows{i} = evaluate_one_binary_combination( ...
                        batch(i,:), ...
                        channelIndices, ...
                        classes, ...
                        channelNames, ...
                        modelSize);
                end
            else
                for i = 1:nBatch
                    rows{i} = evaluate_one_binary_combination( ...
                        batch(i,:), ...
                        channelIndices, ...
                        classes, ...
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

                currentTop = sortrows( ...
                    currentTop, ...
                    {'Accuracy','BalancedAccuracy'}, ...
                    {'descend','descend'});

                if height(currentTop) > topKPerSize
                    currentTop = currentTop(1:topKPerSize,:);
                end
            end

            processed = processed + nBatch;

            fprintf('  %d-channel progress: %.0f / %.0f (%.1f%%)\n', ...
                modelSize, processed, totalCombinations, ...
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

        bestIndices = channel_names_to_indices( ...
            bestRow.Channels(1), channelNames);

        bestCombinedIndex = combine_channel_indices( ...
            channelIndices(:,bestIndices));

        predictedClasses = double(bestCombinedIndex > 0.5);

        bestAccuracy = bestRow.Accuracy(1);
        bestBalancedAccuracy = bestRow.BalancedAccuracy(1);
        bestSensitivity = bestRow.Sensitivity(1);
        bestSpecificity = bestRow.Specificity(1);
        bestChannels = bestRow.Channels(1);

        scoreRows = table( ...
            repmat(modelSize, nSubjects, 1), ...
            repmat(bestChannels, nSubjects, 1), ...
            subjectIDs, ...
            classes, ...
            bestCombinedIndex, ...
            predictedClasses, ...
            repmat(bestAccuracy, nSubjects, 1), ...
            repmat(bestBalancedAccuracy, nSubjects, 1), ...
            repmat(bestSensitivity, nSubjects, 1), ...
            repmat(bestSpecificity, nSubjects, 1), ...
            'VariableNames', { ...
                'NumberOfChannels', ...
                'Channels', ...
                'SubjectID', ...
                'TrueClass', ...
                'CombinedLEAPDIndex', ...
                'PredictedClass', ...
                'Accuracy', ...
                'BalancedAccuracy', ...
                'Sensitivity', ...
                'Specificity'});

        bestScoreTable = [ ...
            bestScoreTable; scoreRows]; %#ok<AGROW>
    end

    if isempty(combinationResults)
        error('No valid channel combinations were evaluated.');
    end
end


function row = evaluate_one_binary_combination( ...
    indices, channelIndices, classes, channelNames, modelSize)

    selectedIndices = channelIndices(:,indices);

    if any(all(~isfinite(selectedIndices),1))
        row = [];
        return;
    end

    combinedIndex = combine_channel_indices(selectedIndices);

    valid = isfinite(combinedIndex) & isfinite(classes);

    if sum(valid) < 2
        row = [];
        return;
    end

    predictedClasses = double(combinedIndex(valid) > 0.5);

    metrics = compute_binary_metrics( ...
        classes(valid), predictedClasses);

    channelText = strjoin(channelNames(indices), ',');

    row = table( ...
        modelSize, ...
        channelText, ...
        metrics.Accuracy, ...
        metrics.BalancedAccuracy, ...
        metrics.Sensitivity, ...
        metrics.Specificity, ...
        metrics.NValid, ...
        'VariableNames', { ...
            'NumberOfChannels', ...
            'Channels', ...
            'Accuracy', ...
            'BalancedAccuracy', ...
            'Sensitivity', ...
            'Specificity', ...
            'NValid'});
end


function validate_combination_settings( ...
    nChannels, minimumCombinationSize, ...
    maximumCombinationSize, topKPerSize, batchSize)

    if minimumCombinationSize < 1 || ...
            maximumCombinationSize < minimumCombinationSize
        error('Invalid channel-combination size range.');
    end

    if maximumCombinationSize > nChannels
        error(['maximumCombinationSize (%d) exceeds the number of ', ...
               'available channels (%d).'], ...
            maximumCombinationSize, nChannels);
    end

    if isempty(topKPerSize) || ...
            ~isfinite(topKPerSize) || topKPerSize < 1
        error('topKPerSize must be a finite positive integer.');
    end

    if isempty(batchSize) || ...
            ~isfinite(batchSize) || batchSize < 1
        error('batchSize must be a finite positive integer.');
    end
end


function indices = channel_names_to_indices(channelText, channelNames)
    names = split(channelText, ',');
    indices = zeros(numel(names),1);

    for j = 1:numel(names)
        idx = find(strcmpi(channelNames, strtrim(names(j))), 1);

        if isempty(idx)
            error('Could not recover channel "%s".', names(j));
        end

        indices(j) = idx;
    end
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
            combination(position) == ...
            nChannels - modelSize + position

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
