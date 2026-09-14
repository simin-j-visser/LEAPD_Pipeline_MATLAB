function tag = make_frequency_grid_tag(lowCutoffsHz, highCutoffsHz)
%MAKE_FREQUENCY_GRID_TAG Return a compact filename-safe grid description.

    lowCutoffsHz = lowCutoffsHz(:);
    highCutoffsHz = highCutoffsHz(:);

    if isempty(lowCutoffsHz) || isempty(highCutoffsHz)
        error('Frequency cutoff grids must not be empty.');
    end

    lowStep = infer_step(lowCutoffsHz);
    highStep = infer_step(highCutoffsHz);

    numberText = @(x) strrep(sprintf('%g', x), '.', 'p');

    tag = sprintf( ...
        'low%s-%s_step%s_high%s-%s_step%s', ...
        numberText(min(lowCutoffsHz)), ...
        numberText(max(lowCutoffsHz)), ...
        numberText(lowStep), ...
        numberText(min(highCutoffsHz)), ...
        numberText(max(highCutoffsHz)), ...
        numberText(highStep));
end


function step = infer_step(values)
    if numel(values) < 2
        step = 0;
    else
        differences = diff(values);
        if max(abs(differences - differences(1))) > 1e-10
            step = NaN;
        else
            step = differences(1);
        end
    end
end
