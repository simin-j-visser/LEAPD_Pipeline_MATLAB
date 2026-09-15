function searchResults = search_all_channels( ...
    dataset, channelNames, context, config)
%SEARCH_ALL_CHANNELS Fast exhaustive per-channel hyperparameter search.
%
% The full hyperparameter grid is still evaluated exactly. To reduce
% runtime and memory, only the best result from each channel is retained.

    nChannels = numel(channelNames);
    bestRows = cell(nChannels,1);

    if ~isfield(config, 'showWaitbar') || isempty(config.showWaitbar)
        config.showWaitbar = false;
    end

    if ~isfield(config, 'progressBandInterval') || ...
            isempty(config.progressBandInterval)
        config.progressBandInterval = 500;
    end

    %% Precompute shared search information once
    searchContext = context;
    searchContext.validBands = create_valid_frequency_bands(config);

    nBands = size(searchContext.validBands,1);

    fprintf('Valid frequency bands: %d\n', nBands);

    fprintf('Designing and caching candidate filters ... ');
    filterTimer = tic;
    searchContext.filterBank = build_filter_bank( ...
        searchContext.validBands, ...
        config.samplingRate);
    fprintf('done (%.1f s).\n', toc(filterTimer));

    switch lower(config.analysisType)

        case 'binary'
            nFolds = context.cvPartition.NumTestSets;
            foldCache.train = cell(nFolds,1);
            foldCache.test = cell(nFolds,1);

            minimumTrainingClassSize = inf;

            for fold = 1:nFolds
                foldCache.train{fold} = ...
                    training(context.cvPartition, fold);
                foldCache.test{fold} = ...
                    test(context.cvPartition, fold);

                trainClasses = ...
                    context.classes(foldCache.train{fold});

                minimumTrainingClassSize = min([ ...
                    minimumTrainingClassSize, ...
                    sum(trainClasses == 1), ...
                    sum(trainClasses == 0)]);
            end

            searchContext.foldCache = foldCache;
            searchContext.maximumSampleDimension = ...
                minimumTrainingClassSize - 1;

        case 'correlation'
            nReference = numel(context.referenceSubjectIDs);
            nFolds = context.cvPartition.NumTestSets;

            foldCache.train = cell(nFolds,1);
            foldCache.test = cell(nFolds,1);
            minimumTrainingTargetSize = inf;

            for fold = 1:nFolds
                foldCache.train{fold} = ...
                    training(context.cvPartition, fold);
                foldCache.test{fold} = ...
                    test(context.cvPartition, fold);

                minimumTrainingTargetSize = min( ...
                    minimumTrainingTargetSize, ...
                    sum(foldCache.train{fold}));
            end

            searchContext.foldCache = foldCache;
            searchContext.maximumSampleDimension = min( ...
                minimumTrainingTargetSize - 1, ...
                nReference - 1);

            if searchContext.maximumSampleDimension < 1
                error('Insufficient subjects for correlation analysis.');
            end

        otherwise
            error('Unknown analysisType: "%s".', config.analysisType);
    end

    %% Progress tracking
    totalTimer = tic;
    completedChannels = 0;
    completedBandTasks = 0;
    totalBandTasks = nChannels * nBands;
    lastPrintedPercent = -1;

    if config.showWaitbar
        progressBar = waitbar(0, ...
            sprintf('Starting LEAPD search: 0/%d channels', nChannels), ...
            'Name', 'LEAPD Hyperparameter Search');
    else
        progressBar = [];
    end

    if config.useParallelChannels

        pool = gcp('nocreate');

        if isempty(pool)
            pool = parpool;
        end

        fprintf('\nParallel search enabled with %d workers.\n', ...
            pool.NumWorkers);

        progressQueue = parallel.pool.DataQueue;
        afterEach(progressQueue, @updateBandProgress);

        channelQueue = parallel.pool.DataQueue;
        afterEach(channelQueue, @updateChannelProgress);

        parfor ch = 1:nChannels

            bestRows{ch} = search_one_channel( ...
                dataset, ...
                channelNames{ch}, ...
                searchContext, ...
                config, ...
                progressQueue);

            send(channelQueue, ch);
        end

    else

        for ch = 1:nChannels

            fprintf('Searching channel %d/%d: %s\n', ...
                ch, nChannels, channelNames{ch});

            bestRows{ch} = search_one_channel( ...
                dataset, ...
                channelNames{ch}, ...
                searchContext, ...
                config, ...
                []);

            updateChannelProgress(ch);
        end
    end

    %% Finish
    totalElapsed = toc(totalTimer);

    if ~isempty(progressBar) && isvalid(progressBar)
        waitbar(1, progressBar, ...
            sprintf('Complete! Total time: %.1f min', ...
                totalElapsed/60));
        pause(1);
        close(progressBar);
    end

    fprintf('\n========================================\n');
    fprintf('LEAPD hyperparameter search complete.\n');
    fprintf('Analysis type: %s\n', config.analysisType);
    fprintf('Total time: %.1f minutes (%.2f hours)\n', ...
        totalElapsed/60, totalElapsed/3600);
    fprintf('========================================\n\n');

    %% Combine only winning per-channel results
    searchResults.bestPerChannel = vertcat(bestRows{:});
    searchResults.allCombinations = table();

    switch lower(config.analysisType)
        case 'binary'
            searchResults.bestPerChannel = sortrows( ...
                searchResults.bestPerChannel, ...
                'CVAccuracy', 'descend');

        case 'correlation'
            searchResults.bestPerChannel = sort_correlation_table( ...
                searchResults.bestPerChannel, ...
                config.selectionCriterion);
    end

    %% Nested progress functions
    function updateBandProgress(nCompletedBands)

        completedBandTasks = completedBandTasks + nCompletedBands;

        fractionComplete = completedBandTasks / totalBandTasks;
        percentComplete = 100 * fractionComplete;

        elapsed = toc(totalTimer);

        if fractionComplete > 0
            estimatedTotalTime = elapsed / fractionComplete;
            remainingTime = estimatedTotalTime - elapsed;
        else
            remainingTime = NaN;
        end

        currentIntegerPercent = floor(percentComplete);

        if currentIntegerPercent > lastPrintedPercent || ...
                completedBandTasks == totalBandTasks

            fprintf(['Search progress: %.1f%% | ' ...
                     'Channels complete: %d/%d | ' ...
                     'Elapsed: %.1f min | ETA: %.1f min\n'], ...
                percentComplete, ...
                completedChannels, ...
                nChannels, ...
                elapsed/60, ...
                remainingTime/60);

            lastPrintedPercent = currentIntegerPercent;
        end

        if ~isempty(progressBar) && isvalid(progressBar)
            waitbar(fractionComplete, progressBar, ...
                sprintf([ ...
                    'Overall search: %.1f%%\n' ...
                    'Channels complete: %d/%d\n' ...
                    'Elapsed: %.1f min\n' ...
                    'Estimated remaining: %.1f min'], ...
                    percentComplete, ...
                    completedChannels, ...
                    nChannels, ...
                    elapsed/60, ...
                    remainingTime/60));
        end
    end

    function updateChannelProgress(ch)
        completedChannels = completedChannels + 1;

        fprintf('Completed channel %d/%d: %s\n', ...
            completedChannels, ...
            nChannels, ...
            string(channelNames{ch}));
    end
end


function validBands = create_valid_frequency_bands(config)
%CREATE_VALID_FREQUENCY_BANDS Build the frequency grid once.
%
% A bandwidth exactly equal to minimumBandwidthHz IS included.

    maximumPossibleBands = ...
        numel(config.lowCutoffsHz) * numel(config.highCutoffsHz);

    validBands = zeros(maximumPossibleBands, 2);
    bandIndex = 0;

    for low = config.lowCutoffsHz
        for high = config.highCutoffsHz
            if (high - low) < config.minimumBandwidthHz || ...
                    high >= config.samplingRate/2
                continue;
            end

            bandIndex = bandIndex + 1;
            validBands(bandIndex,:) = [low, high];
        end
    end

    validBands = validBands(1:bandIndex,:);

    if isempty(validBands)
        error('No valid frequency bands remain after applying constraints.');
    end
end


function tableOut = sort_correlation_table(tableIn, criterion)
    switch lower(criterion)
        case 'min'
            tableOut = sortrows(tableIn, 'SpearmanRho', 'ascend');

        case 'max'
            tableOut = sortrows(tableIn, 'SpearmanRho', 'descend');

        case 'maxabs'
            [~,order] = sort(abs(tableIn.SpearmanRho), 'descend');
            tableOut = tableIn(order,:);

        otherwise
            error('Unknown selection criterion: "%s".', criterion);
    end
end
