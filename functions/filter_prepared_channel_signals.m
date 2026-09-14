function filteredSignals = filter_prepared_channel_signals( ...
    preparedSignals, filterBank, bandIndex)
%FILTER_PREPARED_CHANNEL_SIGNALS Apply one cached band and notch filter.
%
% This preserves the original processing order after segment preparation:
%   band-pass -> notch -> final unit-energy normalization.

    sos = filterBank.SOS{bandIndex};
    g = filterBank.Gain{bandIndex};
    bNotch = filterBank.NotchB;
    aNotch = filterBank.NotchA;

    nSubjects = numel(preparedSignals);
    filteredSignals = cell(nSubjects,1);

    for i = 1:nSubjects
        x = preparedSignals{i};

        x = filtfilt(sos, g, x);
        x = filtfilt(bNotch, aNotch, x);

        signalNorm = norm(x);

        if signalNorm == 0
            error('Subject %d produced a zero-energy filtered signal.', i);
        end

        filteredSignals{i} = x / signalNorm;
    end
end
