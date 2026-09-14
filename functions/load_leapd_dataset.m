function dataset = load_leapd_dataset(matFile)
%LOAD_LEAPD_DATASET Load a LEAPD-compatible dataset from a MAT file.
%
% Accepted MAT layouts:
%
%   1) Top-level variables:
%        EEG
%        Filenames  (or FileNames)
%        ChannelLocations
%
%      Legacy channel-location names are also accepted:
%        Channel_location
%        Channel_locations
%        ChannelLocation
%
%   2) A struct named Dataset containing the same fields.
%
% Returned fields:
%   dataset.EEG
%   dataset.Filenames
%   dataset.ChannelLocations
%   dataset.SourceFile

    if ~isfile(matFile)
        error('Dataset file not found:\n%s', matFile);
    end

    loadedData = load(matFile);

    if isfield(loadedData, 'Dataset') && isstruct(loadedData.Dataset)
        source = loadedData.Dataset;
    else
        source = loadedData;
    end

    if isfield(source, 'EEG')
        EEG = source.EEG;
    else
        error(['Could not find an EEG variable in:\n%s\n\n', ...
               'Expected variable name: EEG'], matFile);
    end

    if isfield(source, 'Filenames')
        Filenames = source.Filenames;
    elseif isfield(source, 'FileNames')
        Filenames = source.FileNames;
    else
        error(['Could not find subject filenames in:\n%s\n\n', ...
               'Expected variable name: Filenames'], matFile);
    end

    if isfield(source, 'ChannelLocations')
        ChannelLocations = source.ChannelLocations;
    elseif isfield(source, 'Channel_location')
        ChannelLocations = source.Channel_location;
    elseif isfield(source, 'Channel_locations')
        ChannelLocations = source.Channel_locations;
    elseif isfield(source, 'ChannelLocation')
        ChannelLocations = source.ChannelLocation;
    else
        availableVariables = fieldnames(source);

        error(['Could not identify the channel-location variable in:\n%s\n\n', ...
               'Accepted names are:\n', ...
               '  ChannelLocations\n', ...
               '  Channel_location\n', ...
               '  Channel_locations\n', ...
               '  ChannelLocation\n\n', ...
               'Variables found:\n  %s'], ...
               matFile, strjoin(availableVariables, '\n  '));
    end

    if isstring(ChannelLocations) || ischar(ChannelLocations)
        ChannelLocations = cellstr(ChannelLocations);
    end

    ChannelLocations = ChannelLocations(:);

    if ~iscell(EEG)
        error('EEG must be stored as a cell array.');
    end

    if isstring(Filenames) || ischar(Filenames)
        Filenames = cellstr(Filenames);
    end

    if ~iscell(Filenames)
        error('Filenames must be a cell array, string array, or character array.');
    end

    if ~iscell(ChannelLocations)
        error('ChannelLocations must be a cell array or string array.');
    end

    if numel(EEG) ~= numel(ChannelLocations)
        error([ ...
            'The number of EEG channel entries (%d) does not match ', ...
            'the number of ChannelLocations entries (%d).'], ...
            numel(EEG), numel(ChannelLocations));
    end

    dataset = struct();
    dataset.EEG = EEG;
    dataset.Filenames = Filenames;
    dataset.ChannelLocations = ChannelLocations;
    dataset.SourceFile = matFile;
end
