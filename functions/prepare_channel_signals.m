function preparedSignals = prepare_channel_signals( ...
    signals, samplingRate, notchFrequencyHz, notchQualityFactor)
%PREPARE_CHANNEL_SIGNALS Perform band-independent preprocessing once.
%
% Processing for each subject:
%   1. Convert to double.
%   2. Normalize each segment independently to unit energy.
%   3. Average segments.
%   4. Apply the line-noise notch filter.
%
% The candidate band-pass filter and final unit-energy normalization are
% applied later by filter_prepared_channel_signals. This keeps the notch
% outside the frequency-search loop because the notch settings do not
% depend on the candidate low/high cutoffs.

    validateattributes( ...
        samplingRate, ...
        {'numeric'}, ...
        {'scalar','positive'});

    validateattributes( ...
        notchFrequencyHz, ...
        {'numeric'}, ...
        {'scalar','positive'});

    validateattributes( ...
        notchQualityFactor, ...
        {'numeric'}, ...
        {'scalar','positive'});

    nyquist = samplingRate / 2;
    normalizedNotch = notchFrequencyHz / nyquist;

    if normalizedNotch <= 0 || normalizedNotch >= 1
        error( ...
            'Invalid notch frequency: %.3f Hz.', ...
            notchFrequencyHz);
    end

    notchBandwidth = normalizedNotch / notchQualityFactor;

    [bNotch, aNotch] = ...
        iirnotch( ...
            normalizedNotch, ...
            notchBandwidth);

    nSubjects = numel(signals);
    preparedSignals = cell(nSubjects,1);

    for i = 1:nSubjects

        x = double(signals{i});

        if isempty(x) || any(~isfinite(x(:)))
            error( ...
                'Subject %d contains empty or non-finite data.', ...
                i);
        end

        if isvector(x)
            x = x(:);
        end

        %% Normalize each segment independently
        segmentNorms = sqrt(sum(x.^2, 1));

        if any(segmentNorms == 0)
            error( ...
                'Subject %d contains a zero-energy segment.', ...
                i);
        end

        x = x ./ segmentNorms;

        %% Average segments
        x = mean(x, 2);

        %% Apply notch once before the frequency-search band-pass loop
        x = filtfilt(bNotch, aNotch, x);

        preparedSignals{i} = x;
    end
end
