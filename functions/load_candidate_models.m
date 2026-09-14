function candidateModels = load_candidate_models( ...
    hyperparameterFile, excludedChannels)
%LOAD_CANDIDATE_MODELS Load fixed per-channel hyperparameters.

    if ~isfile(hyperparameterFile)
        error('Hyperparameter file not found:\n%s', ...
            hyperparameterFile);
    end

    loadedData = load(hyperparameterFile);

    if isfield(loadedData, 'searchResults') && ...
            isfield(loadedData.searchResults, 'bestPerChannel')

        candidateModels = ...
            loadedData.searchResults.bestPerChannel;

    elseif isfield(loadedData, 'candidateModels')
        candidateModels = loadedData.candidateModels;

    else
        error(['Could not find channel hyperparameter results in:\n%s'], ...
            hyperparameterFile);
    end

    requiredVariables = { ...
        'Channel', ...
        'LowCutoffHz', ...
        'HighCutoffHz', ...
        'LPCOrder', ...
        'PCADimension'};

    for i = 1:numel(requiredVariables)
        if ~ismember( ...
                requiredVariables{i}, ...
                candidateModels.Properties.VariableNames)

            error('Required variable "%s" is missing.', ...
                requiredVariables{i});
        end
    end

    candidateModels.Channel = string(candidateModels.Channel);

    if ~isempty(excludedChannels)
        excludeMask = ismember( ...
            upper(candidateModels.Channel), ...
            upper(string(excludedChannels)));

        candidateModels(excludeMask,:) = [];
    end

    if isempty(candidateModels)
        error('No candidate channels remain.');
    end
end
