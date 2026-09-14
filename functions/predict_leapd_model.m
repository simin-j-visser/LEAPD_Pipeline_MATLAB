function [scores, predictedClasses, distances] = ...
    predict_leapd_model(model, features, useNormalizedProjection)
%PREDICT_LEAPD_MODEL Compute binary LEAPD scores and predictions.
%
% Unified LEAPD convention used throughout this pipeline:
%
%   score = distance-to-class-0 / ...
%           (distance-to-class-1 + distance-to-class-0)
%
% Therefore:
%   score >  0.5 predicts class 1
%   score <= 0.5 predicts class 0
%
% Higher LEAPD score = more class-1-like.
%
% The optional normalized-projection mode is retained for compatibility.
% The default setting is false.

    nSubjects = size(features,1);

    distance1 = zeros(nSubjects,1);
    distance0 = zeros(nSubjects,1);

    for i = 1:nSubjects
        x = features(i,:);

        centered1 = x - model.Class1Mean;
        centered0 = x - model.Class0Mean;

        if useNormalizedProjection
            projection1 = centered1 * model.Class1Basis;
            projection0 = centered0 * model.Class0Basis;

            distance1(i) = safe_ratio( ...
                norm(projection1), norm(centered1));

            distance0(i) = safe_ratio( ...
                norm(projection0), norm(centered0));
        else
            residual1 = centered1 - ...
                (centered1 * model.Class1Basis) * ...
                model.Class1Basis';

            residual0 = centered0 - ...
                (centered0 * model.Class0Basis) * ...
                model.Class0Basis';

            distance1(i) = norm(residual1);
            distance0(i) = norm(residual0);
        end
    end

    denominator = distance1 + distance0;
    denominator(denominator == 0) = eps;

    scores = distance0 ./ denominator;
    predictedClasses = double(scores > 0.5);

    distances = table( ...
        distance1, ...
        distance0, ...
        'VariableNames', { ...
            'DistanceToClass1', ...
            'DistanceToClass0'});
end


function value = safe_ratio(numerator, denominator)
    if denominator == 0
        value = 0;
    else
        value = numerator / denominator;
    end
end
