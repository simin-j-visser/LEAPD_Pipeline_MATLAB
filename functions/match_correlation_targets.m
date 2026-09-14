function targetValues = match_correlation_targets( ...
    subjectIDs, targetData, requireAll)
%MATCH_CORRELATION_TARGETS Match target values to dataset subject order.
%
% requireAll = true:
%   every subject must have a finite matched target value.
%
% requireAll = false:
%   unmatched or non-finite targets are returned as NaN.

    if nargin < 3
        requireAll = true;
    end

    datasetIDs = string(subjectIDs(:));
    targetIDs = string(targetData.SubjectIDs(:));

    [matched, locations] = ismember(datasetIDs, targetIDs);

    targetValues = nan(numel(datasetIDs),1);

    if any(matched)
        targetValues(matched) = ...
            targetData.Values(locations(matched));
    end

    if requireAll
        invalid = ~matched | ~isfinite(targetValues);

        if any(invalid)
            missingIDs = datasetIDs(invalid);

            error(['Finite target values were not found for:\n%s'], ...
                strjoin(missingIDs, newline));
        end
    end
end
