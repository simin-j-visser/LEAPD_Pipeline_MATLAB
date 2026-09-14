function model = fit_leapd_model(features, classes, pcaDimension)
%FIT_LEAPD_MODEL Fit one affine PCA subspace for each binary class.

    features = double(features);
    classes = classes(:);

    class1 = features(classes == 1, :);
    class0 = features(classes == 0, :);

    if isempty(class1) || isempty(class0)
        error('Both classes must be present in the training data.');
    end

    maxDimension = min([ ...
        size(features,2), ...
        size(class1,1)-1, ...
        size(class0,1)-1]);

    if pcaDimension < 1 || pcaDimension > maxDimension
        error('PCA dimension %d is invalid; maximum is %d.', ...
            pcaDimension, maxDimension);
    end

    [mean1, basis1] = fit_class_subspace(class1, pcaDimension);
    [mean0, basis0] = fit_class_subspace(class0, pcaDimension);

    model.Class1Mean = mean1;
    model.Class1Basis = basis1;
    model.Class0Mean = mean0;
    model.Class0Basis = basis0;
    model.PCADimension = pcaDimension;
end


function [classMean, basis] = ...
    fit_class_subspace(classFeatures, dimension)

    classMean = mean(classFeatures, 1);
    centered = classFeatures - classMean;

    [~,~,V] = svd(centered, 'econ');
    basis = V(:,1:dimension);
end
