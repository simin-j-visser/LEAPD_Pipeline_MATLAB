function [cvPartition, foldInfo] = load_or_create_correlation_cv_folds( ...
    subjectIDs, numberOfFolds, randomSeed, foldFile)
%LOAD_OR_CREATE_CORRELATION_CV_FOLDS Reproducible CV folds for correlation.
%
% numberOfFolds = 1 creates leave-one-out cross-validation.
% integer > 1 creates ordinary K-fold CV over the target/group-1 subjects.
%
% The reference/group-0 subjects are not partitioned because they are not
% the subjects receiving clinical target values in the correlation task.

    subjectIDs = cellstr(string(subjectIDs(:)));
    nSubjects = numel(subjectIDs);

    if nSubjects < 2
        error('At least two target subjects are required.');
    end

    if isfile(foldFile)
        loaded = load(foldFile);

        required = { ...
            'cvPartition', ...
            'savedSubjectIDs', ...
            'savedNumberOfFolds', ...
            'savedRandomSeed'};

        if all(isfield(loaded, required))
            sameIDs = isequal( ...
                cellstr(string(loaded.savedSubjectIDs(:))), ...
                subjectIDs);

            sameSettings = ...
                loaded.savedNumberOfFolds == numberOfFolds && ...
                loaded.savedRandomSeed == randomSeed;

            if sameIDs && sameSettings
                cvPartition = loaded.cvPartition;
                foldInfo.message = sprintf( ...
                    'reused saved folds from %s', foldFile);
                return;
            end
        end
    end

    rng(randomSeed, 'twister');

    if numberOfFolds == 1
        cvPartition = cvpartition(nSubjects, 'LeaveOut');
    elseif numberOfFolds > 1 && numberOfFolds < nSubjects
        cvPartition = cvpartition(nSubjects, 'KFold', numberOfFolds);
    else
        error(['numberOfFolds must be 1 for leave-one-out or an ', ...
               'integer between 2 and N-1.']);
    end

    savedSubjectIDs = subjectIDs;
    savedNumberOfFolds = numberOfFolds;
    savedRandomSeed = randomSeed;

    save(foldFile, ...
        'cvPartition', ...
        'savedSubjectIDs', ...
        'savedNumberOfFolds', ...
        'savedRandomSeed');

    foldInfo.message = sprintf( ...
        'created and saved new folds to %s', foldFile);
end
