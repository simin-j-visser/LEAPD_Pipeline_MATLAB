function metrics = evaluate_predictions(trueClasses, predictedClasses)
%EVALUATE_PREDICTIONS Compute binary classification metrics.

    trueClasses = trueClasses(:);
    predictedClasses = predictedClasses(:);

    TP = sum(trueClasses == 1 & predictedClasses == 1);
    TN = sum(trueClasses == 0 & predictedClasses == 0);
    FP = sum(trueClasses == 0 & predictedClasses == 1);
    FN = sum(trueClasses == 1 & predictedClasses == 0);

    metrics.Accuracy = (TP + TN) / numel(trueClasses);
    metrics.Sensitivity = divide_or_nan(TP, TP + FN);
    metrics.Specificity = divide_or_nan(TN, TN + FP);
    metrics.BalancedAccuracy = mean( ...
        [metrics.Sensitivity, metrics.Specificity], ...
        'omitnan');

    metrics.ConfusionMatrix = [TN FP; FN TP];
end


function value = divide_or_nan(numerator, denominator)
    if denominator == 0
        value = NaN;
    else
        value = numerator / denominator;
    end
end
