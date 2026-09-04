# OptimalRoll Simulation and Weight Calibration

## Purpose

The simulation module plays complete games with the same domain rules and
Advisor implementation as the Flutter application. Its first goal is to make
strategy changes measurable. Its second goal is to search for Advisor weights
that maximize the final score rather than only the score of the current turn.

## Deterministic game rolls

Every potential die value is derived from four coordinates:

```text
game seed + turn index + roll index + die index
```

The random sequence is therefore unaffected by how many dice a strategy keeps
or whether it scores early. Two strategies evaluated on the same seeds face the
same potential rolls. Score differences can be compared per seed and have much
less random noise than results produced by unrelated random streams.

## Simulation invariants

`GameSimulator` validates every action before applying it. A simulated strategy
cannot:

- make a fourth roll,
- reroll an empty selection,
- score an occupied or otherwise illegal field,
- use a normal figure score when a from-hand score should be doubled,
- finish before the scorecard is complete.

A new game contains 69 empty fields and therefore lasts exactly 69 turns. The
simulator also supports a partially filled initial state for focused tests.

## Running simulations

Run one complete game with the default weights:

```powershell
dart run tool/simulate_games.dart --games 1 --seed 1
```

Compare the default strategy with the greedy baseline on identical seeds:

```powershell
dart run tool/simulate_games.dart `
  --games 100 `
  --seed 1000 `
  --workers 8 `
  --compare-baseline
```

Use `--json` for machine-readable output. The report includes total score,
school and figure components, bonuses, pijols, figures scored from hand, roll
count, percentiles and throughput.

The `greedy` profile sets every strategic weight to zero. It still uses the
exact within-turn probability solver, which makes it a useful baseline for
measuring whether long-term heuristics improve complete-game results.
`turn-score-only` remains as a backwards-compatible alias.

An optimizer result can be replayed and compared with the current defaults:

```powershell
dart run tool/simulate_games.dart `
  --weights tool/results/advisor-weights-v2.json `
  --games 1000 `
  --seed 5000000 `
  --workers 8 `
  --compare-default
```

## Weight optimization

The optimizer currently searches:

- value of opening a figure column,
- early and late opportunity cost of Chance,
- base cost of a pijol,
- risk cost of losing a perfect-column bonus,
- dynamic value of school progress,
- value of completing a school section,
- separate pijol opportunity costs for basic, rare, compound, straight,
  parity, Small and Chance figure groups.

The normal figure opportunity cost and pijol opportunity cost are separate.
Scoring a valid figure and permanently crossing it out are different strategic
decisions and no longer share one parameter.

The initial population contains the current default profile, the zero-weight
baseline and random candidates. After each generation, the best candidates are
retained and mutated. Every candidate in an experiment uses the same training
seeds.

Training sample size grows geometrically from `--min-training-games` to
`--training-games`. Weak profiles are therefore eliminated using a cheap
sample, while surviving profiles receive increasingly reliable evaluation.
Several final candidates are evaluated on validation seeds. The best validated
candidate is selected and evaluated once more on untouched test seeds. Only the
blind test controls the adoption recommendation.

Example exploratory run:

```powershell
dart run tool/optimize_advisor_weights.dart `
  --population 12 `
  --generations 8 `
  --min-training-games 20 `
  --training-games 200 `
  --finalists 3 `
  --validation-games 500 `
  --test-games 2000 `
  --workers 8 `
  --seed 10000 `
  --profile-name advisor-weights-v2 `
  --output tool/results/advisor-weights-v2.json
```

Optimizer defaults are intentionally tiny and only verify that the pipeline
works. They do not produce statistically useful weights.

When a surviving profile advances to a larger training sample, previously
simulated seeds are reused and only the additional games are calculated. The
JSON result stores all finalists, their paired validation comparisons, the
blind test result and the final adoption decision.

## Interpreting results

The main optimization objective is the mean final `GameState.total`. School
bonuses and perfect-column bonuses are already part of this value and must not
be rewarded a second time. Pijol and score-component metrics are diagnostic.

Candidate profiles should be compared on paired seeds. A useful final report
should include:

- mean paired score difference,
- 95% confidence interval for that difference,
- candidate win and tie rates,
- score percentiles,
- pijol and perfect-column rates.

Training, validation and final test seeds should remain separate. Final test
seeds must not be reused to choose weights.

## Current performance

After caching dice histograms, figure evaluations, best scoring moves and
reroll values, one complete default-Advisor game takes about 0.4 seconds on the
development machine. Before this optimization it took about 5 seconds. An
eight-game batch reached about 2.56 games per second on one worker and 5.89
games per second on four workers.

The simulation CLI reports games per second so performance changes can be
measured rather than estimated.

## First exploratory calibration

The first small experiment used 8 candidates, 4 generations, 12 training games
per candidate and 48 validation games. Its training winner scored 1601.75 on
the training seeds, compared with 1524.25 for the current defaults. On unseen
validation seeds it scored 1465.21, while the current defaults scored 1478.27.
The paired difference was `-13.06 +/- 35.99` points.

This profile is intentionally stored as an exploratory result and must not be
adopted. It demonstrates why training and validation seeds must remain
separate. The optimizer now validates several finalists and then uses a third,
untouched seed range for the blind adoption test. A profile is marked as a
validated improvement only when there are at least 30 blind test games and the
complete 95% confidence interval for its paired score difference is above zero.

A second smoke experiment exercised the v2 grouped pijol and school parameters,
three finalists and a 30-game blind test. Its selected profile scored
`-8.67 +/- 41.60` points relative to the defaults on the blind seeds, so it was
also rejected and retained only as `advisor-weights-exploratory-v2.json`.

## Adopted candidate-v3 calibration

The first production calibration used 16 candidates over 8 generations. The
progressive training sample grew from 20 to 250 games, four finalists were
evaluated on 500 separate validation games, and the selected finalist was
tested once on 2,000 untouched blind-test seeds.

The selected profile averaged 1518.76 points on the blind test, compared with
1478.85 for the previous defaults. Its paired improvement was
`39.91 +/- 6.80` points at 95% confidence, with a 59.85% win rate and 0.20% tie
rate. The complete confidence interval was above zero, so the profile passed
the adoption gate and is now used by `const AdvisorWeights()`.

The previous defaults remain available as `AdvisorWeights.baselineV1` for
reproducible comparisons. The complete experiment, including all finalist
weights and score distributions, is stored in
`tool/results/advisor-weights-candidate-v3.json`.
