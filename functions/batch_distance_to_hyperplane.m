function distances = batch_distance_to_hyperplane( ...
    features, basis, meanVector, useNormalizedProjection)
%BATCH_DISTANCE_TO_HYPERPLANE Vectorized LEAPD class-subspace measure.

    if nargin < 4
        useNormalizedProjection = false;
    end

    centered = features - meanVector;

    if useNormalizedProjection
        projectionCoordinates = centered * basis;

        numerators = sqrt(sum(projectionCoordinates.^2, 2));
        denominators = sqrt(sum(centered.^2, 2));

        distances = zeros(size(denominators));

        valid = denominators > 0;
        distances(valid) = ...
            numerators(valid) ./ denominators(valid);
    else
        residual = centered - ...
            (centered * basis) * basis';

        distances = sqrt(sum(residual.^2, 2));
    end
end
