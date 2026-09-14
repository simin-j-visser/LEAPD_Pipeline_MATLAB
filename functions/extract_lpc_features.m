function features = extract_lpc_features(filteredSignals, lpcOrder)
%EXTRACT_LPC_FEATURES Estimate AR/LPC coefficients with Burg's method.
%
% The leading polynomial coefficient, which is always 1, is removed.
% Output size: number of subjects x lpcOrder.

    nSubjects = numel(filteredSignals);
    features = zeros(nSubjects, lpcOrder);

    for i = 1:nSubjects
        coefficients = arburg(filteredSignals{i}, lpcOrder);
        features(i,:) = real(coefficients(2:end));
    end
end
