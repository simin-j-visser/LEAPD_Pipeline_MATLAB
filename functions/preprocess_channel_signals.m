function filteredSignals = preprocess_channel_signals( ...
    signals, samplingRate, lowCutoffHz, highCutoffHz, ...
    notchFrequencyHz, notchQualityFactor)
%PREPROCESS_CHANNEL_SIGNALS Average segments, filter, and normalize.
%
% Processing order for each subject:
%   1. Normalize each segment independently to unit energy.
%   2. Average segments.
%   3. Apply a sixth-order Butterworth candidate band-pass filter.
%   4. Apply a line-noise notch filter.
%   5. Normalize the final signal to unit energy.
%
% Each subject may be:
%   - a time-series vector, or
%   - a time-by-segment matrix.

    validateattributes(samplingRate, ...
        {'numeric'}, {'scalar','positive'});

    validateattributes(notchQualityFactor, ...
        {'numeric'}, {'scalar','positive'});

    nyquist = samplingRate / 2;

    if lowCutoffHz <= 0 || ...
            highCutoffHz >= nyquist || ...
            lowCutoffHz >= highCutoffHz

        error('Invalid band-pass range: %.3f-%.3f Hz.', ...
            lowCutoffHz, highCutoffHz);
    end

    [z,p,k] = butter(6, ...
        [lowCutoffHz highCutoffHz] / nyquist, ...
        'bandpass');

    [sosBandpass,gBandpass] = zp2sos(z,p,k);

    normalizedNotch = notchFrequencyHz / nyquist;

    if normalizedNotch <= 0 || normalizedNotch >= 1
        error('Invalid notch frequency: %.3f Hz.', ...
            notchFrequencyHz);
    end

    notchBandwidth = ...
        normalizedNotch / notchQualityFactor;

    [bNotch,aNotch] = iirnotch( ...
        normalizedNotch, notchBandwidth);

    nSubjects = numel(signals);
    filteredSignals = cell(nSubjects,1);

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

        x = mean(x,2);
        x = filtfilt(sosBandpass, gBandpass, x);
        x = filtfilt(bNotch, aNotch, x);

        signalNorm = norm(x);

        if signalNorm == 0
            error('Subject %d produced a zero-energy filtered signal.', i);
        end

        filteredSignals{i} = x / signalNorm;
    end
end
