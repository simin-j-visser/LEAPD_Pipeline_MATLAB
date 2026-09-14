function distance = distance_to_hyperplane( ...
    featureVector, basis, meanVector, useNormalizedProjection)
%DISTANCE_TO_HYPERPLANE Return the LEAPD class-subspace measure.
%
% Default (useNormalizedProjection = false):
%   Euclidean residual distance to the affine PCA hyperplane.
%
% Compatibility mode (useNormalizedProjection = true):
%   Norm of the projection coordinates divided by the norm of the centered
%   feature vector, matching the earlier binary LEAPD implementation.

    if nargin < 4
        useNormalizedProjection = false;
    end

    centered = featureVector - meanVector;

    if useNormalizedProjection
        denominator = norm(centered);

        if denominator == 0
            distance = 0;
        else
            projectionCoordinates = centered * basis;
            distance = norm(projectionCoordinates) / denominator;
        end
    else
        residual = centered - ...
            (centered * basis) * basis';

        distance = norm(residual);
    end
end
