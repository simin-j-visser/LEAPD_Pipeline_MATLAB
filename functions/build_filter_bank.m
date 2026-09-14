function filterBank = build_filter_bank( ...
    validBands, samplingRate, notchFrequencyHz, notchQualityFactor)
%BUILD_FILTER_BANK Design reusable candidate filters once.

    validateattributes(samplingRate, ...
        {'numeric'}, {'scalar','positive'});

    validateattributes(notchQualityFactor, ...
        {'numeric'}, {'scalar','positive'});

    nyquist = samplingRate / 2;
    nBands = size(validBands,1);

    filterBank.SOS = cell(nBands,1);
    filterBank.Gain = cell(nBands,1);

    for bandIndex = 1:nBands
        low = validBands(bandIndex,1);
        high = validBands(bandIndex,2);

        if low <= 0 || high >= nyquist || low >= high
            error('Invalid band-pass range: %.3f-%.3f Hz.', low, high);
        end

        [z,p,k] = butter(6, ...
            [low high] / nyquist, ...
            'bandpass');

        [sos,g] = zp2sos(z,p,k);

        filterBank.SOS{bandIndex} = sos;
        filterBank.Gain{bandIndex} = g;
    end

    normalizedNotch = notchFrequencyHz / nyquist;

    if normalizedNotch <= 0 || normalizedNotch >= 1
        error('Invalid notch frequency: %.3f Hz.', notchFrequencyHz);
    end

    notchBandwidth = normalizedNotch / notchQualityFactor;

    [filterBank.NotchB, filterBank.NotchA] = ...
        iirnotch(normalizedNotch, notchBandwidth);
end
