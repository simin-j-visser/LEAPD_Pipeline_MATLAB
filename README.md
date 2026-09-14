# LEAPD MATLAB Pipeline

A unified MATLAB implementation of the LEAPD workflow for two analysis modes:

- `binary` — binary classification using class-specific LPC/PCA hyperplanes.
- `correlation` — correlation of LEAPD indices with a continuous subject-level target.

The analysis mode is selected with one setting in each main script:

```matlab
config.analysisType = 'binary';
```

or

```matlab
config.analysisType = 'correlation';
```

## Main scripts

Run the scripts in order as needed:

1. `main_01_select_hyperparameters.m`
   - Performs the channel-wise hyperparameter search on the development dataset.
   - Both modes support configurable leave-one-out or K-fold cross-validation.
   - Binary mode selects by out-of-fold accuracy only.
   - Correlation mode computes Spearman correlation only after all target-subject out-of-fold LEAPD scores are assembled.
   - The search reuses each PCA/SVD decomposition across all tested PCA dimensions.
   - Only the best result per channel is retained; its subject-level LEAPD scores are saved with the winning hyperparameters.

2. `main_02_evaluate_same_dataset.m`
   - Reuses the channel-specific hyperparameters selected in step 1.
   - Evaluates requested single- and multi-channel combinations on the development dataset.
   - Both modes combine out-of-fold LEAPD indices using the same CV scheme as step 1.

3. `main_03_evaluate_out_of_sample.m`
   - Fits final channel models using all development subjects.
   - Transfers only the channel-specific hyperparameters to the test analysis:
     frequency band, LPC order, and PCA dimension.
   - Channel combinations are evaluated on the test dataset; they are not fixed from the development dataset.


## Cross-validation

The same setting is available for both analysis modes in steps 1 and 2:

```matlab
config.numberOfFolds = 1;
```

- `1` = leave-one-out cross-validation (LOOCV)
- integer `> 1` = K-fold cross-validation

For correlation, only target/group-1 subjects are partitioned. In each fold, the target hyperplane is fit from target training subjects, held-out target subjects receive OOF LEAPD scores, and the reference/group-0 hyperplane is fit from all reference subjects. Spearman rho is calculated once from the complete OOF score vector and the clinical target vector.

## Shared preprocessing

Both analysis modes use exactly the same preprocessing implementation:

1. Normalize each available segment independently to unit energy.
2. Average segments within each subject.
3. Apply the candidate sixth-order Butterworth band-pass filter.
4. Apply a 60-Hz notch filter.
5. Normalize the final filtered signal to unit energy.
6. Estimate Burg AR/LPC coefficients.

The legacy 5.5–6.5 Hz FFT stop-band step is intentionally not included.

## LEAPD index

This version uses one direction convention in both analysis modes: **higher LEAPD index = more group-1/class-1-like**.

For a feature vector `x`, the LEAPD index is

```text
distance to group 0 / reference hyperplane
------------------------------------------------
distance to group 1 + distance to group 0
```

With the default group ordering, group 1 is the target/class-1 group and group 0 is the reference/class-0 group. Therefore, a sample closer to group 1 has a larger LEAPD index.

For binary classification in the standard residual-distance mode, the decision rule is:

```text
LEAPD index >  0.5  -> class 1
LEAPD index <= 0.5  -> class 0
```

The optional `useNormalizedProjection` setting is retained for compatibility with the earlier binary pipeline. The default is `false`.

## Multi-channel combination

Single-channel LEAPD indices are combined using the geometric mean of odds:

```text
odds_k = index_k / (1 - index_k)
combined_odds = geometric mean(odds_k)
combined_index = combined_odds / (1 + combined_odds)
```

The code performs the equivalent calculation in log-odds space for numerical stability.

## Expected dataset format

The MAT file should contain either top-level variables or a `Dataset` struct containing:

```matlab
EEG
Filenames
ChannelLocations
```

Legacy channel-location names are also accepted:

```matlab
Channel_location
Channel_locations
ChannelLocation
```

For grouped development/binary test data:

```matlab
EEG{channel}{1}    % group 1 / class 1 subjects
EEG{channel}{2}    % group 0 / class 0 subjects

Filenames{1}       % group 1 IDs
Filenames{2}       % group 0 IDs
```

For a correlation test dataset containing only the target group, either of these layouts is accepted:

```matlab
EEG{channel}{1}    % target group
Filenames{1}
```

or

```matlab
EEG{channel}       % directly contains target subject signals
Filenames
```

Each subject signal may be a vector or a time-by-segment matrix.

## Continuous targets

Correlation mode uses a spreadsheet with a subject-ID column and a numeric target column. Configure them in the main script:

```matlab
config.subjectIDColumn = 'ID';
config.targetColumn = 'UPDRS';
```

For a negative association such as a mortality-survival analysis, use:

```matlab
config.selectionCriterion = 'min';
```

For the largest positive association:

```matlab
config.selectionCriterion = 'max';
```

For the largest absolute association:

```matlab
config.selectionCriterion = 'maxabs';
```

## Test-set combination search

In `main_03_evaluate_out_of_sample.m`, channel-specific hyperparameters are fixed from development, but channel combinations are evaluated and ranked using the test outcomes. Therefore, the best multi-channel result is a test-set combination search, not the performance of a prespecified channel combination. The code and output names are intentionally explicit about this distinction.

## MATLAB requirements

The code uses functionality from:

- MATLAB
- Signal Processing Toolbox (`butter`, `filtfilt`, `iirnotch`, `arburg`)
- Statistics and Machine Learning Toolbox (`cvpartition`, `corr`)
- Parallel Computing Toolbox is optional; set the parallel settings to `false` if unavailable.

## Recommended workflow

Before running:

1. Put development/test MAT files in `data/`.
2. Put continuous-target spreadsheets in `data/` when using correlation mode.
3. Edit only the `USER SETTINGS` section at the top of each main script.
4. Keep the analysis type consistent across all three scripts.
5. Re-run the hyperparameter search whenever preprocessing or the search grid changes.

## Editable hyperparameter grid

In `main_01_select_hyperparameters.m`, edit only `config.grid` to change the exhaustive frequency/LPC search. The pipeline automatically builds `lowCutoffsHz`, `highCutoffsHz`, and uses a bandwidth rule that includes a band exactly equal to `minimumBandwidthHz`.

```matlab
config.grid.lowStartHz = 2.5;
config.grid.lowStopHz = 95;
config.grid.lowStepHz = 1;
config.grid.highStartHz = 5;
config.grid.highStopHz = 100;
config.grid.highStepHz = 1;
config.grid.minimumBandwidthHz = 4;
config.grid.lpcOrders = 2:10;
```
