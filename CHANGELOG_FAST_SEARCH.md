## Hyperparameter search

- Binary model selection uses **CV accuracy only**.
- Binary PCA dimensions are evaluated in one CV pass; each class SVD is computed once per fold/order and reused across all PCA dimensions.
- Correlation PCA dimensions are evaluated in one OOF CV pass; the reference SVD is computed once and the target SVD is computed once per fold/order, then reused across all PCA dimensions.
- The exhaustive frequency/LPC/PCA grid is still searched; only the winning result for each channel is retained.
- `searchResults.allCombinations` is intentionally an empty table to avoid storing millions of candidate rows.
- The winning model for each channel is rerun once with the standard evaluator to save subject-level LEAPD scores.

## Saved per-channel output

Binary winners save:
- Channel
- LowCutoffHz
- HighCutoffHz
- LPCOrder
- PCADimension
- CVAccuracy
- SubjectIDs
- TrueClasses
- LEAPDScores
- PredictedClasses

Correlation winners save:
- Channel
- LowCutoffHz
- HighCutoffHz
- LPCOrder
- PCADimension
- SpearmanRho
- PValue
- SubjectIDs
- TargetValues
- LEAPDScores

## Score direction

Both modes now use one convention:

`higher LEAPD score = more group-1 / class-1 / target-like`

Binary:

`score = d(class 0) / (d(class 1) + d(class 0))`

Class 1 is predicted when `score > 0.5`.

Correlation:

`score = d(reference) / (d(target) + d(reference))`

Because this is the complement of the previous correlation index, Spearman rho changes sign relative to the prior pipeline. `maxabs` ranking is unchanged; to reproduce an old signed search, swap `max` and `min`.

## Frequency grid

The step-1 defaults are now:

- low cutoff: `2.5:1:95`
- high cutoff: `5:1:100`
- minimum bandwidth: 4 Hz, **including exactly 4 Hz**
- LPC order: 2:10

## Configurable search grid
- Frequency-grid start/stop/step values now live in `config.grid` in `main_01_select_hyperparameters.m`.
- Minimum bandwidth and LPC orders are also controlled from the same grid block.
- A bandwidth exactly equal to the configured minimum remains included.

## Configurable CV for both modes
- Binary and correlation now share `config.numberOfFolds`.
- `1` means LOOCV; any valid integer greater than 1 means K-fold CV.
- Correlation rho is computed from the complete target-subject OOF LEAPD score vector, never by averaging fold-wise correlations.
- Step 2 uses the same fold files/scheme as step 1.
