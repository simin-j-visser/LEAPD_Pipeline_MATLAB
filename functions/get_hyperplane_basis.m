function [basis, meanVector] = get_hyperplane_basis(features, dimension)
%GET_HYPERPLANE_BASIS Return the top PCA directions of centered features.
%
% features  : N x K matrix
% dimension : requested subspace dimension
%
% basis      : K x dimension orthonormal basis
% meanVector : 1 x K feature mean

    [nSubjects, nFeatures] = size(features);

    if nSubjects < 2
        error('At least two subjects are required to define a hyperplane.');
    end

    if dimension < 1
        error('Hyperplane dimension must be at least 1.');
    end

    meanVector = mean(features, 1);
    centered = features - meanVector;

    [~,~,rightVectors] = svd(centered, 'econ');

    maximumDimension = min( ...
        [size(rightVectors,2), nSubjects - 1, nFeatures]);

    if dimension > maximumDimension
        error(['Requested dimension %d exceeds the maximum valid ', ...
               'dimension %d.'], dimension, maximumDimension);
    end

    basis = rightVectors(:,1:dimension);
end
