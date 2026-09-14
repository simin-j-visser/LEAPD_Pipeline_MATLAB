function combinedIndex = combine_channel_indices(channelIndices)
%COMBINE_CHANNEL_INDICES Combine LEAPD indices by geometric-mean odds.
%
% The calculation is performed in log-odds space for numerical stability.

    bounded = min(max(channelIndices, eps), 1 - eps);

    logOdds = log(bounded) - log1p(-bounded);

    validCount = sum(isfinite(logOdds), 2);
    meanLogOdds = mean(logOdds, 2, 'omitnan');

    combinedIndex = 1 ./ (1 + exp(-meanLogOdds));
    combinedIndex(validCount == 0) = NaN;
end
