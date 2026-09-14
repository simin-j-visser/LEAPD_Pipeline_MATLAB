function finalModels = fit_correlation_channel_models( ...
    developmentData, candidateModels, config)
%FIT_CORRELATION_CHANNEL_MODELS Fit final target/reference hyperplanes.

    nChannels = height(candidateModels);
    finalModels = repmat(struct(), nChannels, 1);

    for k = 1:nChannels
        channelName = char(candidateModels.Channel(k));

        fprintf('Fitting correlation channel %d/%d: %s\n', ...
            k, nChannels, channelName);

        channelData = get_channel_data( ...
            developmentData, channelName);

        allSignals = [ ...
            channelData.group1Signals; ...
            channelData.group0Signals];

        filtered = preprocess_channel_signals( ...
            allSignals, ...
            config.samplingRate, ...
            candidateModels.LowCutoffHz(k), ...
            candidateModels.HighCutoffHz(k), ...
            config.notchFrequencyHz, ...
            config.notchQualityFactor);

        features = extract_lpc_features( ...
            filtered, candidateModels.LPCOrder(k));

        nTarget = numel(channelData.group1Signals);

        targetFeatures = features(1:nTarget,:);
        referenceFeatures = features(nTarget+1:end,:);

        dimension = candidateModels.PCADimension(k);

        [targetBasis, targetMean] = ...
            get_hyperplane_basis( ...
                targetFeatures, dimension);

        [referenceBasis, referenceMean] = ...
            get_hyperplane_basis( ...
                referenceFeatures, dimension);

        finalModels(k).Channel = string(channelName);
        finalModels(k).LowCutoffHz = candidateModels.LowCutoffHz(k);
        finalModels(k).HighCutoffHz = candidateModels.HighCutoffHz(k);
        finalModels(k).LPCOrder = candidateModels.LPCOrder(k);
        finalModels(k).PCADimension = dimension;

        finalModels(k).TargetMean = targetMean;
        finalModels(k).TargetBasis = targetBasis;
        finalModels(k).ReferenceMean = referenceMean;
        finalModels(k).ReferenceBasis = referenceBasis;
    end
end
