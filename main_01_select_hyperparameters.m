clear; clc;

%% USER SETTINGS
projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'functions'));

resultsFolder = fullfile(projectRoot, 'results');
if ~isfolder(resultsFolder), mkdir(resultsFolder); end

% Choose: 'binary' or 'correlation'
config.analysisType = 'binary';

config.developmentFile = fullfile( ...
    projectRoot, 'data', 'development_dataset.mat');

config.samplingRate = 500;

% Hyperparameter grid
% Edit ONLY this block when you want to change the search grid.
config.grid.lowStartHz = 2.5;
config.grid.lowStopHz = 95;
config.grid.lowStepHz = 1;

config.grid.highStartHz = 5;
config.grid.highStopHz = 100;
config.grid.highStepHz = 1;

% A bandwidth exactly equal to this value IS included.
config.grid.minimumBandwidthHz = 4;

% LPC model orders included in the exhaustive search.
config.grid.lpcOrders = 2:10;

% Build the actual vectors used by the search.
config.lowCutoffsHz = ...
    config.grid.lowStartHz : ...
    config.grid.lowStepHz : ...
    config.grid.lowStopHz;

config.highCutoffsHz = ...
    config.grid.highStartHz : ...
    config.grid.highStepHz : ...
    config.grid.highStopHz;

config.minimumBandwidthHz = ...
    config.grid.minimumBandwidthHz;

config.lpcOrders = ...
    config.grid.lpcOrders;

% Shared preprocessing
config.notchFrequencyHz = 60;
config.notchQualityFactor = 35;

% Distance option. false reproduces the standard residual-distance LEAPD.
config.useNormalizedProjection = false;

% Parallelize across channels.
config.useParallelChannels = true;

% Progress settings.
config.showWaitbar = false;
config.progressBandInterval = 500;

% Default: retain all channels.
config.excludedChannels = {};

%% CROSS-VALIDATION SETTINGS
% Shared by BOTH binary and correlation analyses.
% 1 = leave-one-out; integer >1 = K-fold.
config.numberOfFolds = 1;
config.randomSeed = 1;

%% ANALYSIS-SPECIFIC SETTINGS
switch lower(config.analysisType)

    case 'binary'
        config.foldFile = fullfile( ...
            resultsFolder, 'development_cv_folds_binary.mat');

    case 'correlation'
        config.foldFile = fullfile( ...
            resultsFolder, 'development_cv_folds_correlation.mat');
        config.targetFile = fullfile( ...
            projectRoot, 'data', 'development_targets.xlsx');

        config.subjectIDColumn = 'ID';
        config.targetColumn = 'Target';

        % 'min', 'max', or 'maxabs'
        config.selectionCriterion = 'max';

    otherwise
        error('Unknown analysisType: "%s".', config.analysisType);
end

%% AUTOMATIC RESULTS FILE
gridTag = make_frequency_grid_tag( ...
    config.lowCutoffsHz, config.highCutoffsHz);

resultLabel = lower(config.analysisType);

if strcmpi(config.analysisType, 'correlation')
    targetLabel = matlab.lang.makeValidName(config.targetColumn);
    resultLabel = sprintf('correlation_%s', targetLabel);
end

config.resultsFile = fullfile( ...
    resultsFolder, ...
    sprintf('hyperparameter_results_%s_%s.mat', ...
        resultLabel, gridTag));

%% LOAD DEVELOPMENT DATASET
developmentData = load_leapd_dataset(config.developmentFile);

channelNames = string(developmentData.ChannelLocations(:));

if ~isempty(config.excludedChannels)
    channelNames(ismember( ...
        upper(channelNames), ...
        upper(string(config.excludedChannels)))) = [];
end

if isempty(channelNames)
    error('No channels remain after exclusions.');
end

channelNames = cellstr(channelNames);

%% BUILD ANALYSIS CONTEXT
context = struct();

switch lower(config.analysisType)

    case 'binary'
        [~, classes, subjectIDs] = ...
            get_binary_channel_data( ...
                developmentData, channelNames{1});

        [cvPartition, foldInfo] = load_or_create_cv_folds( ...
            subjectIDs, ...
            classes, ...
            config.numberOfFolds, ...
            config.randomSeed, ...
            config.foldFile);

        fprintf('Cross-validation folds: %s\n', foldInfo.message);

        context.classes = classes;
        context.subjectIDs = subjectIDs;
        context.cvPartition = cvPartition;

    case 'correlation'
        firstChannel = get_channel_data( ...
            developmentData, channelNames{1});

        targetData = load_correlation_targets( ...
            config.targetFile, ...
            config.subjectIDColumn, ...
            config.targetColumn);

        targetValues = match_correlation_targets( ...
            firstChannel.group1IDs, targetData, true);

        fprintf('Matched %d target values for "%s".\n', ...
            numel(targetValues), config.targetColumn);

        [cvPartition, foldInfo] = ...
            load_or_create_correlation_cv_folds( ...
                firstChannel.group1IDs, ...
                config.numberOfFolds, ...
                config.randomSeed, ...
                config.foldFile);

        fprintf('Cross-validation folds: %s\n', foldInfo.message);

        context.targetSubjectIDs = firstChannel.group1IDs;
        context.referenceSubjectIDs = firstChannel.group0IDs;
        context.targetValues = targetValues;
        context.cvPartition = cvPartition;
end

%% SEARCH HYPERPARAMETERS
searchResults = search_all_channels( ...
    developmentData, channelNames, context, config);

save(config.resultsFile, ...
    'searchResults', 'config', '-v7.3');

fprintf('\nSaved results to:\n%s\n', config.resultsFile);
disp(searchResults.bestPerChannel);
