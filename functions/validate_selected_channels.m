function validate_selected_channels( ...
    developmentData, testData, channelNames)
%VALIDATE_SELECTED_CHANNELS Verify requested channels exist in both datasets.

    developmentChannels = string( ...
        developmentData.ChannelLocations(:));

    testChannels = string( ...
        testData.ChannelLocations(:));

    requestedChannels = string(channelNames(:));

    missingDevelopment = requestedChannels( ...
        ~ismember(upper(requestedChannels), ...
                  upper(developmentChannels)));

    missingTest = requestedChannels( ...
        ~ismember(upper(requestedChannels), ...
                  upper(testChannels)));

    if ~isempty(missingDevelopment)
        error(['Channels missing from development dataset:\n%s'], ...
            strjoin(missingDevelopment, newline));
    end

    if ~isempty(missingTest)
        error(['Channels missing from test dataset:\n%s'], ...
            strjoin(missingTest, newline));
    end
end
