function [signals, subjectIDs] = ...
    get_target_channel_data(dataset, channelName)
%GET_TARGET_CHANNEL_DATA Extract target-group subjects for one channel.
%
% Supported test-data layouts:
%
%   Grouped:
%       EEG{channel}{1} = target subjects
%       Filenames{1}    = target subject IDs
%
%   Target-only:
%       EEG{channel}    = cell array of target subject signals
%       Filenames       = cell array of target subject IDs

    channelIndex = find(strcmpi( ...
        dataset.ChannelLocations, channelName), 1);

    if isempty(channelIndex)
        error('Channel "%s" was not found in %s.', ...
            channelName, dataset.SourceFile);
    end

    channelEntry = dataset.EEG{channelIndex};

    if ~iscell(channelEntry) || isempty(channelEntry)
        error('EEG{%d} must be a non-empty cell array.', channelIndex);
    end

    if iscell(channelEntry{1})
        signals = channelEntry{1};

        if isempty(dataset.Filenames) || ...
                ~iscell(dataset.Filenames{1})
            error(['Grouped test data require target IDs in ', ...
                   'Filenames{1}.']);
        end

        subjectIDs = dataset.Filenames{1};
    else
        signals = channelEntry;
        subjectIDs = dataset.Filenames;
    end

    signals = signals(:);
    subjectIDs = cellstr(string(subjectIDs(:)));

    if numel(signals) ~= numel(subjectIDs)
        error(['Signal count and filename count do not match ', ...
               'for channel "%s".'], channelName);
    end
end
