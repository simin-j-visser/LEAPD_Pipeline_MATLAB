function hyperparameterFile = resolve_hyperparameter_file( ...
    resultsFolder, analysisType, requestedFile)
%RESOLVE_HYPERPARAMETER_FILE Resolve a step-1 result file safely.
%
% If requestedFile is non-empty, it is used directly.
% If requestedFile is empty, exactly one matching result file must exist.

    if nargin >= 3 && ~isempty(requestedFile)
        hyperparameterFile = requestedFile;

        if ~isfile(hyperparameterFile)
            error('Hyperparameter file not found:\n%s', ...
                hyperparameterFile);
        end

        return;
    end

    pattern = sprintf( ...
        'hyperparameter_results_%s_*.mat', ...
        lower(analysisType));

    matches = dir(fullfile(resultsFolder, pattern));

    if isempty(matches)
        error(['No hyperparameter result file matching\n  %s\n', ...
               'was found in:\n%s'], ...
            pattern, resultsFolder);
    end

    if numel(matches) > 1
        names = string({matches.name});

        error([ ...
            'More than one matching hyperparameter file was found.\n', ...
            'Set config.hyperparameterFile explicitly.\n\n%s'], ...
            strjoin(names, newline));
    end

    hyperparameterFile = fullfile( ...
        matches(1).folder, matches(1).name);
end
