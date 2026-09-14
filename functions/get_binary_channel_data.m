function [signals, classes, subjectIDs] = ...
    get_binary_channel_data(dataset, channelName)
%GET_BINARY_CHANNEL_DATA Return one channel as a single ordered subject list.
%
% Ordering:
%   class 1 subjects first, then class 0 subjects.

    channelData = get_channel_data(dataset, channelName);

    nClass1 = numel(channelData.group1Signals);
    nClass0 = numel(channelData.group0Signals);

    signals = [ ...
        channelData.group1Signals; ...
        channelData.group0Signals];

    classes = [ ...
        ones(nClass1,1); ...
        zeros(nClass0,1)];

    subjectIDs = [ ...
        channelData.group1IDs; ...
        channelData.group0IDs];
end
