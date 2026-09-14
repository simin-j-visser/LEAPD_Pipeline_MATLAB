function metrics = compute_binary_metrics(trueClasses, predictedClasses)
%COMPUTE_BINARY_METRICS Binary metrics returned as percentages.

    trueClasses = trueClasses(:);
    predictedClasses = predictedClasses(:);

    valid = isfinite(trueClasses) & isfinite(predictedClasses);

    raw = evaluate_predictions( ...
        trueClasses(valid), ...
        predictedClasses(valid));

    metrics = struct();
    metrics.Accuracy = 100 * raw.Accuracy;
    metrics.BalancedAccuracy = 100 * raw.BalancedAccuracy;
    metrics.Sensitivity = 100 * raw.Sensitivity;
    metrics.Specificity = 100 * raw.Specificity;
    metrics.NValid = sum(valid);
end
