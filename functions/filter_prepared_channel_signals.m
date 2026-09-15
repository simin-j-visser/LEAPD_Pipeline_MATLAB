function filteredSignals = filter_prepared_channel_signals( ...
    preparedSignals, filterBank, bandIndex)
%FILTER_PREPARED_CHANNEL_SIGNALS Apply one cached candidate band-pass filter.
%
% Memory-safe fast version:
%   - Signals are processed in small subject batches.
%   - This reduces filtfilt call overhead without building one huge matrix.
%
% Input signals should already be:
%   1. segment-normalized,
%   2. averaged across segments,
%   3. notch-filtered.
%
% This function applies:
%   1. candidate band-pass filter,
%   2. final unit-energy normalization.

    sos = filterBank.SOS{bandIndex};
    g = filterBank.Gain{bandIndex};

    nSubjects = numel(preparedSignals);
    filteredSignals = cell(nSubjects,1);

    % Increase to 6 or 8 if RAM is fine.
    % Decrease to 2 if MATLAB runs out of memory.
    maxBatchSubjects = 6;

    signalLengths = zeros(nSubjects,1);

    for i = 1:nSubjects
        signalLengths(i) = numel(preparedSignals{i});
    end

    uniqueLengths = unique(signalLengths);

    for lengthIndex = 1:numel(uniqueLengths)

        currentLength = uniqueLengths(lengthIndex);
        subjectIndicesAll = find(signalLengths == currentLength);
        nGroupSubjects = numel(subjectIndicesAll);

        for batchStart = 1:maxBatchSubjects:nGroupSubjects

            batchEnd = min( ...
                batchStart + maxBatchSubjects - 1, ...
                nGroupSubjects);

            subjectIndices = subjectIndicesAll(batchStart:batchEnd);
            nBatchSubjects = numel(subjectIndices);

            X = zeros(currentLength, nBatchSubjects);

            for j = 1:nBatchSubjects
                X(:,j) = preparedSignals{subjectIndices(j)}(:);
            end

            % MATLAB filters each column as an independent signal.
            Y = filtfilt(sos, g, X);

            signalNorms = sqrt(sum(Y.^2, 1));

            if any(signalNorms == 0)
                badLocalIndex = find(signalNorms == 0, 1, 'first');
                badSubject = subjectIndices(badLocalIndex);

                error( ...
                    'Subject %d produced a zero-energy filtered signal.', ...
                    badSubject);
            end

            Y = Y ./ signalNorms;

            for j = 1:nBatchSubjects
                filteredSignals{subjectIndices(j)} = Y(:,j);
            end

            clear X Y
        end
    end
end
