function featuresByOrder = extract_lpc_features_all_orders( ...
    filteredSignals, lpcOrders)
%EXTRACT_LPC_FEATURES_ALL_ORDERS Compute Burg LPC features efficiently.
%
% Burg recursion is run once at the largest requested order for each
% subject. Lower-order AR polynomials are reconstructed from the leading
% reflection coefficients, which are the same recursion stages used by
% separate lower-order Burg fits.

    lpcOrders = lpcOrders(:)';

    if isempty(lpcOrders)
        error('lpcOrders cannot be empty.');
    end

    maximumOrder = max(lpcOrders);
    nSubjects = numel(filteredSignals);
    nOrders = numel(lpcOrders);

    reflectionBySubject = cell(nSubjects,1);

    for i = 1:nSubjects
        [~,~,reflectionBySubject{i}] = ...
            arburg(filteredSignals{i}, maximumOrder);
    end

    featuresByOrder = cell(nOrders,1);

    for orderIndex = 1:nOrders
        order = lpcOrders(orderIndex);
        features = zeros(nSubjects, order);

        for i = 1:nSubjects
            reflection = reflectionBySubject{i};
            coefficients = rc2poly(reflection(1:order));
            features(i,:) = real(coefficients(2:end));
        end

        featuresByOrder{orderIndex} = features;
    end
end
