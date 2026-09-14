function targetData = load_correlation_targets( ...
    targetFile, subjectIDColumn, targetColumn)
%LOAD_CORRELATION_TARGETS Load continuous subject-level target values.

    if ~isfile(targetFile)
        error('Target file not found:\n%s', targetFile);
    end

    tableData = readtable( ...
        targetFile, 'VariableNamingRule', 'preserve');

    variableNames = tableData.Properties.VariableNames;

    if ~ismember(subjectIDColumn, variableNames)
        error('Subject ID column "%s" was not found.', ...
            subjectIDColumn);
    end

    if ~ismember(targetColumn, variableNames)
        error('Target column "%s" was not found.', ...
            targetColumn);
    end

    subjectIDs = cellstr(string( ...
        tableData.(subjectIDColumn)));

    rawValues = tableData.(targetColumn);

    if isnumeric(rawValues)
        values = double(rawValues);
    else
        values = str2double(string(rawValues));
    end

    values = values(:);

    if numel(unique(string(subjectIDs))) ~= numel(subjectIDs)
        error('Duplicate subject IDs were found in the target file.');
    end

    if ~any(isfinite(values))
        error('No finite numeric target values were found.');
    end

    targetData = struct();
    targetData.SubjectIDs = subjectIDs(:);
    targetData.Values = values;
    targetData.TargetName = targetColumn;
end
