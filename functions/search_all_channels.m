function searchResults = search_all_channels( ...
    dataset, channelNames, context, config)
%SEARCH_ALL_CHANNELS Fast exhaustive per-channel hyperparameter search.
%
% The full hyperparameter grid is still evaluated exactly. To reduce
% runtime and memory, only the best result from each channel is retained.
%
% Binary selection criterion:
%   maximum cross-validated accuracy only.
%
% Correlation selection criterion:
%   config.selectionCriterion = 'min', 'max', or 'maxabs'.
%
% For the winning model of each channel, the subject-level LEAPD scores are
% recomputed with the standard (non-search) evaluation function and stored
% together with the selected hyperparameters.

    nChannels = numel(channelNames);
    bestRows = cell(nChannels,1);

    %% PRECOMPUTE SHARED SEARCH INFORMATION
    searchContext = context;

    searchContext.validBands = ...
        create_valid_frequency_bands(config);

    fprintf('Valid frequency bands: %d\n', ...
        size(searchContext.validBands,1));

    fprintf('Designing and caching candidate filters ... ');

    filterTimer = tic;

    searchContext.filterBank = build_filter_bank( ...
        searchContext.validBands, ...
        config.samplingRate, ...
        config.notchFrequencyHz, ...
        config.notchQualityFactor);

    fprintf('done (%.1f s).\n', toc(filterTimer));

    %% PRECOMPUTE CROSS-VALIDATION INFORMATION
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
            nReference = ...
                numel(context.referenceSubjectIDs);

            nFolds = ...
                context.cvPartition.NumTestSets;

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
                error( ...
                    'Insufficient subjects for correlation analysis.');
            end


        otherwise
            error( ...
                'Unknown analysisType: "%s".', ...
                config.analysisType);
    end

    %% PROGRESS TRACKING
    totalTimer = tic;
    completedChannels = 0;

    progressBar = waitbar( ...
        0, ...
        sprintf( ...
            'Starting LEAPD search: 0/%d channels', ...
            nChannels), ...
        'Name', ...
        'LEAPD Hyperparameter Search');

    %% SEARCH ALL CHANNELS
    if config.useParallelChannels

        %% START OR REUSE PARALLEL POOL
        pool = gcp('nocreate');

        if isempty(pool)
            pool = parpool;
        end

        %% MAKE ALL LEAPD FUNCTIONS AVAILABLE TO WORKERS
        %
        % Explicit attachment prevents workers from losing access to
        % functions that may be required later in the search, including
        % the standard evaluation functions used after model selection.

        functionsFolder = ...
            fileparts(mfilename('fullpath'));

        functionInfo = ...
            dir(fullfile(functionsFolder, '*.m'));

        functionFiles = fullfile( ...
            {functionInfo.folder}, ...
            {functionInfo.name});

        addAttachedFiles(pool, functionFiles);

        fprintf( ...
            '\nParallel search enabled with %d workers.\n', ...
            pool.NumWorkers);

        %% PARALLEL PROGRESS QUEUE
        progressQueue = ...
            parallel.pool.DataQueue;

        afterEach( ...
            progressQueue, ...
            @updateProgress);

        %% PARALLEL CHANNEL SEARCH
        parfor ch = 1:nChannels

            bestRows{ch} = search_one_channel( ...
                dataset, ...
                channelNames{ch}, ...
                searchContext, ...
                config);

            send(progressQueue, ch);
        end

    else

        %% SERIAL CHANNEL SEARCH
        for ch = 1:nChannels

            fprintf( ...
                'Searching channel %d/%d: %s\n', ...
                ch, ...
                nChannels, ...
                channelNames{ch});

            bestRows{ch} = search_one_channel( ...
                dataset, ...
                channelNames{ch}, ...
                searchContext, ...
                config);

            updateProgress(ch);
        end
    end

    %% FINISH
    totalElapsed = toc(totalTimer);

    if isvalid(progressBar)

        waitbar( ...
            1, ...
            progressBar, ...
            sprintf( ...
                'Complete! Total time: %.1f min', ...
                totalElapsed / 60));

        pause(1);
        close(progressBar);
    end

    fprintf('\n========================================\n');
    fprintf('LEAPD hyperparameter search complete.\n');
    fprintf('Analysis type: %s\n', config.analysisType);

    fprintf( ...
        'Total time: %.1f minutes (%.2f hours)\n', ...
        totalElapsed / 60, ...
        totalElapsed / 3600);

    fprintf('========================================\n\n');

    %% COMBINE WINNING PER-CHANNEL RESULTS
    searchResults.bestPerChannel = ...
        vertcat(bestRows{:});

    % Retained as an empty table for backward compatibility with code that
    % checks whether this field exists. The exhaustive candidate table is
    % intentionally not stored because it can contain millions of rows.
    searchResults.allCombinations = table();

    %% SORT RESULTS
    switch lower(config.analysisType)

        case 'binary'

            searchResults.bestPerChannel = ...
                sortrows( ...
                    searchResults.bestPerChannel, ...
                    'CVAccuracy', ...
                    'descend');


        case 'correlation'

            searchResults.bestPerChannel = ...
                sort_correlation_table( ...
                    searchResults.bestPerChannel, ...
                    config.selectionCriterion);
    end

    %% NESTED PROGRESS FUNCTION
    function updateProgress(~)

        completedChannels = ...
            completedChannels + 1;

        elapsed = toc(totalTimer);

        fractionComplete = ...
            completedChannels / nChannels;

        percentComplete = ...
            100 * fractionComplete;

        estimatedTotalTime = ...
            elapsed / fractionComplete;

        remainingTime = ...
            estimatedTotalTime - elapsed;

        fprintf( ...
            ['Progress: %d/%d channels | %.1f%% | ' ...
             'Elapsed: %.1f min | ETA: %.1f min\n'], ...
            completedChannels, ...
            nChannels, ...
            percentComplete, ...
            elapsed / 60, ...
            remainingTime / 60);

        if isvalid(progressBar)

            waitbar( ...
                fractionComplete, ...
                progressBar, ...
                sprintf( ...
                    ['Completed: %d/%d channels (%.1f%%)\n' ...
                     'Elapsed: %.1f min\n' ...
                     'Estimated remaining: %.1f min'], ...
                    completedChannels, ...
                    nChannels, ...
                    percentComplete, ...
                    elapsed / 60, ...
                    remainingTime / 60));
        end
    end
end


function validBands = create_valid_frequency_bands(config)
%CREATE_VALID_FREQUENCY_BANDS Build the frequency grid once.
%
% A bandwidth exactly equal to minimumBandwidthHz IS included.

    maximumPossibleBands = ...
        numel(config.lowCutoffsHz) * ...
        numel(config.highCutoffsHz);

    validBands = ...
        zeros(maximumPossibleBands, 2);

    bandIndex = 0;

    for low = config.lowCutoffsHz

        for high = config.highCutoffsHz

            if (high - low) < config.minimumBandwidthHz || ...
                    high >= config.samplingRate / 2

                continue;
            end

            bandIndex = bandIndex + 1;

            validBands(bandIndex,:) = ...
                [low, high];
        end
    end

    validBands = ...
        validBands(1:bandIndex,:);

    if isempty(validBands)

        error( ...
            ['No valid frequency bands remain after ' ...
             'applying constraints.']);
    end
end


function tableOut = ...
    sort_correlation_table(tableIn, criterion)

    switch lower(criterion)

        case 'min'

            tableOut = sortrows( ...
                tableIn, ...
                'SpearmanRho', ...
                'ascend');


        case 'max'

            tableOut = sortrows( ...
                tableIn, ...
                'SpearmanRho', ...
                'descend');


        case 'maxabs'

            [~, order] = sort( ...
                abs(tableIn.SpearmanRho), ...
                'descend');

            tableOut = ...
                tableIn(order,:);


        otherwise

            error( ...
                'Unknown selection criterion: "%s".', ...
                criterion);
    end
end
