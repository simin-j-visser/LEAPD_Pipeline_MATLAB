function channelData = get_channel_data(dataset, channelName)
%GET_CHANNEL_DATA Return the two grouped subject sets for one channel.
%
% Expected grouped layout:
%   EEG{channel}{1} = group 1 / class 1 / target group
%   EEG{channel}{2} = group 0 / class 0 / reference group
%
%   Filenames{1} = group 1 IDs
%   Filenames{2} = group 0 IDs

    channelIndex = find(strcmpi( ...
        dataset.ChannelLocations, channelName), 1);

    if isempty(channelIndex)
        error('Channel "%s" was not found in %s.', ...
            channelName, dataset.SourceFile);
    end

    channelEntry = dataset.EEG{channelIndex};

    if ~iscell(channelEntry) || numel(channelEntry) ~= 2
        error(['EEG{%d} must contain exactly two group cells for ', ...
               'grouped development/binary analysis.'], ...
            channelIndex);
    end

    group1Signals = channelEntry{1};
    group0Signals = channelEntry{2};

    if ~iscell(group1Signals) || ~iscell(group0Signals)
        error('Both channel groups must be cell arrays of subject signals.');
    end

    group1Signals = group1Signals(:);
    group0Signals = group0Signals(:);

    if numel(dataset.Filenames) < 2 || ...
            ~iscell(dataset.Filenames{1}) || ...
            ~iscell(dataset.Filenames{2})
        error('Grouped data require Filenames{1} and Filenames{2}.');
    end

    group1IDs = cellstr(string(dataset.Filenames{1}(:)));
    group0IDs = cellstr(string(dataset.Filenames{2}(:)));

    if numel(group1Signals) ~= numel(group1IDs)
        error(['Group-1 signal and filename counts do not match for ', ...
               'channel "%s".'], channelName);
    end

    if numel(group0Signals) ~= numel(group0IDs)
        error(['Group-0 signal and filename counts do not match for ', ...
               'channel "%s".'], channelName);
    end

    channelData = struct();
    channelData.group1Signals = group1Signals;
    channelData.group0Signals = group0Signals;
    channelData.group1IDs = group1IDs;
    channelData.group0IDs = group0IDs;
end
