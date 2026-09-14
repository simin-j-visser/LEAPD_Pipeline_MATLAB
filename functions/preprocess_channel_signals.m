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
% This wrapper preserves the original public interface. The exhaustive
% search uses the same operations through cached helper functions so the
% band-independent work is not repeated for every candidate band.

    preparedSignals = prepare_channel_signals(signals);

    filterBank = build_filter_bank( ...
        [lowCutoffHz highCutoffHz], ...
        samplingRate, ...
        notchFrequencyHz, ...
        notchQualityFactor);

    filteredSignals = filter_prepared_channel_signals( ...
        preparedSignals, filterBank, 1);
end
