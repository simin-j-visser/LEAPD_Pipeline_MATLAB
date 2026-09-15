function featuresByOrder = extract_lpc_features_all_orders( ...
    filteredSignals, lpcOrders)
%EXTRACT_LPC_FEATURES_ALL_ORDERS Compute Burg LPC features efficiently.
%
% Fast version:
%   - Burg recursion is run once at the largest requested order.
%   - Lower-order AR coefficients are reconstructed directly from the
%     reflection coefficients.
%   - Repeated rc2poly calls are avoided inside the frequency-search loop.

    lpcOrders = lpcOrders(:)';

    if isempty(lpcOrders)
        error('lpcOrders cannot be empty.');
    end

    if any(lpcOrders < 1) || any(mod(lpcOrders,1) ~= 0)
        error('All LPC orders must be positive integers.');
    end

    maximumOrder = max(lpcOrders);
    nSubjects = numel(filteredSignals);
    nOrders = numel(lpcOrders);

    featuresByOrder = cell(nOrders,1);

    for orderIndex = 1:nOrders
        order = lpcOrders(orderIndex);
        featuresByOrder{orderIndex} = zeros(nSubjects, order);
    end

    orderToIndex = zeros(1, maximumOrder);

    for orderIndex = 1:nOrders
        orderToIndex(lpcOrders(orderIndex)) = orderIndex;
    end

    for subjectIndex = 1:nSubjects

        x = filteredSignals{subjectIndex};

        [~,~,reflection] = arburg(x, maximumOrder);

        arPolynomial = 1;

        for order = 1:maximumOrder

            previousPolynomial = arPolynomial;

            arPolynomial = ...
                [previousPolynomial, 0] + ...
                reflection(order) * [0, fliplr(conj(previousPolynomial))];

            outputIndex = orderToIndex(order);

            if outputIndex ~= 0
                featuresByOrder{outputIndex}(subjectIndex,:) = ...
                    real(arPolynomial(2:end));
            end
        end
    end
end
