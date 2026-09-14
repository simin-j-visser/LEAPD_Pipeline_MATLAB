function [cvPartition, foldInfo] = load_or_create_cv_folds( ...
    subjectIDs, classes, numberOfFolds, randomSeed, foldFile)
%LOAD_OR_CREATE_CV_FOLDS Create reproducible binary CV folds or reuse them.
%
% numberOfFolds = 1 creates leave-one-out cross-validation.

    subjectIDs = cellstr(string(subjectIDs(:)));
    classes = classes(:);

    if numel(subjectIDs) ~= numel(classes)
        error('Subject-ID and class counts do not match.');
    end

    if ~all(ismember(unique(classes), [0 1]))
        error('Binary classes must contain only 0 and 1.');
    end

    if isfile(foldFile)
        loaded = load(foldFile);

        required = {'cvPartition','savedSubjectIDs','savedClasses', ...
            'savedNumberOfFolds','savedRandomSeed'};

        if all(isfield(loaded, required))
            sameIDs = isequal( ...
                cellstr(string(loaded.savedSubjectIDs(:))), ...
                subjectIDs);

            sameClasses = isequal( ...
                loaded.savedClasses(:), classes);

            sameSettings = ...
                loaded.savedNumberOfFolds == numberOfFolds && ...
                loaded.savedRandomSeed == randomSeed;

            if sameIDs && sameClasses && sameSettings
                cvPartition = loaded.cvPartition;
                foldInfo.message = sprintf( ...
                    'reused saved folds from %s', foldFile);
                return;
            end
        end
    end

    rng(randomSeed, 'twister');

    if numberOfFolds == 1
        cvPartition = cvpartition(numel(classes), 'LeaveOut');
    elseif numberOfFolds > 1 && numberOfFolds < numel(classes)
        cvPartition = cvpartition(classes, 'KFold', numberOfFolds);
    else
        error(['numberOfFolds must be 1 for leave-one-out or an ', ...
               'integer between 2 and N-1.']);
    end

    savedSubjectIDs = subjectIDs;
    savedClasses = classes;
    savedNumberOfFolds = numberOfFolds;
    savedRandomSeed = randomSeed;

    save(foldFile, ...
        'cvPartition', ...
        'savedSubjectIDs', ...
        'savedClasses', ...
        'savedNumberOfFolds', ...
        'savedRandomSeed');

    foldInfo.message = sprintf( ...
        'created and saved new folds to %s', foldFile);
end
