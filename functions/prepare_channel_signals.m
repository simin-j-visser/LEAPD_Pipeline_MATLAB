function preparedSignals = prepare_channel_signals(signals)
%PREPARE_CHANNEL_SIGNALS Perform band-independent preprocessing once.
%
% Processing for each subject:
%   1. Convert to double.
%   2. Normalize each segment independently to unit energy.
%   3. Average segments.
%
% The output remains a cell array to keep memory use low during parallel
% exhaustive searches.

    nSubjects = numel(signals);
    preparedSignals = cell(nSubjects,1);

    for i = 1:nSubjects
        x = double(signals{i});

        if isempty(x) || any(~isfinite(x(:)))
            error('Subject %d contains empty or non-finite data.', i);
        end

        if isrow(x)
            x = x(:);
        end

        for segment = 1:size(x,2)
            segmentNorm = norm(x(:,segment));

            if segmentNorm == 0
                error('Subject %d contains a zero-energy segment.', i);
            end

            x(:,segment) = x(:,segment) / segmentNorm;
        end

        preparedSignals{i} = mean(x,2);
    end
end
