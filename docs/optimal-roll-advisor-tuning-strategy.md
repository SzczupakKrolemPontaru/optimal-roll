# Optimal Roll Advisor Tuning Strategy

## Purpose

The goal of this document is to define a reproducible strategy for improving
the Advisor's average game score. The current weight optimizer can improve the
existing policy, but reaching a substantially higher target such as 1800
points will likely require tuning the decision policy itself, not only its
scoring weights.

The central rule is:

> Use fast heuristics to eliminate weak candidates, but use the exact Advisor
> for final training, validation, and holdout decisions.

The fast strategy is an exploration tool. It must not silently replace the
production Advisor or become the only source of optimized weights.

## Current limitation

The current `AdvisorWeights` mainly influence the utility assigned to scoring
options:

- opening a figure column;
- using Chance early or late in the game;
- taking a Pijol;
- risking a perfect column;
- progressing through a school column;
- completing a school column;
- sacrificing different Pijol figure groups.

They do not directly control several important policy decisions:

- when to stop a turn and score immediately;
- when to keep chasing a figure;
- how aggressively to reroll dice;
- how risk tolerance should change during the game;
- whether late-game points should be preferred over long-term column value.

Consequently, searching a larger number of values inside the current weight
space may produce diminishing returns. A result around 1800 should be treated
as a hypothesis to test, not as a guaranteed outcome of weight optimization.

## Recommended optimization pipeline

The tuning pipeline should have four distinct stages:

```text
large candidate population
        |
        v
fast heuristic filter
        |
        v
exact Advisor training
        |
        v
exact validation and finalist selection
        |
        v
large shared holdout
```

Each stage has a different purpose and should use different game budgets.

### Stage 0: establish baselines

Before tuning, record the same-seed performance of:

1. the current production Advisor;
2. the greedy strategy;
3. the fast exploration strategy;
4. any previously accepted weight profile.

At minimum, record:

- mean and median score;
- confidence interval;
- school score and school bonuses;
- figure score;
- Pijol count and Pijol penalties;
- perfect-column bonuses;
- figures scored from hand;
- rolls and dice rolled per game.

The fast strategy must be benchmarked separately. If it has a materially lower
ceiling than the exact Advisor, it should only be used as a rough pre-filter.

### Stage 1: fast candidate filtering

Generate a much larger population than is practical with the exact solver.
For example:

- 100–300 candidates;
- 20–50 games per candidate;
- several independent random seeds;
- the lightweight exploration strategy.

The purpose is not to obtain final weights. The purpose is to discard clearly
weak regions of the search space cheaply.

The fast strategy should be used through an explicit option such as:

```powershell
dart run tool/tune_advisor_weights.dart --fast-exploration
```

This mode must remain opt-in. It should never change the default application
behavior or the exact validation path.

The preferred long-term implementation is a true pre-filter: fast evaluation
should rank candidates first, then only the top candidates should enter exact
training. Replacing all exact training with fast training is less reliable
because the two policies optimize different behavior.

### Stage 2: exact Advisor training

Take the best fast-filtered candidates and evaluate them with the exact dynamic
programming Advisor. A practical starting point is:

- 10–30 finalists from the fast stage;
- 100–300 games per candidate;
- two or more independent seed ranges;
- the current wide weight search space.

The exact Advisor must be used here because it is the policy whose final game
performance matters. Candidate rankings from the fast heuristic should not be
accepted without this confirmation.

### Stage 3: validation and holdout

Validation should use unseen seeds and should be large enough to reduce noise.
The best few candidates should then be tested against the same baseline on one
shared holdout sample.

Suggested initial budgets:

- exact validation: 300–1000 games per finalist;
- shared holdout: 3000–10000 games;
- final adoption test: a fresh seed range not used anywhere else.

A candidate should only replace production weights when its confidence interval
and fresh adoption test support a meaningful improvement. A positive mean
difference with a confidence interval crossing zero is not strong evidence of
an improvement.

## Tune policy parameters in addition to weights

The next major improvement should be expanding the optimized object from only
`AdvisorWeights` to a complete policy configuration:

```text
AdvisorPolicy
  weights
  strategy parameters
```

Useful strategy parameters include:

- `minimumScoreToStop`;
- `figureChaseThreshold`;
- `rerollAggressiveness`;
- `earlyGameRiskMultiplier`;
- `lateGameRiskMultiplier`;
- `schoolPriorityEarly`;
- `schoolPriorityLate`;
- `scoreNowMargin`;
- `perfectColumnProtectionMargin`.

These parameters should first be added with conservative bounds. The optimizer
should be allowed to change them only in simulation tools, while the UI keeps
using the normal Advisor configuration.

## Use game phases

The value of a decision changes as the scorecard fills. A single global set of
weights is unlikely to express this well.

Start with three phases based on the proportion of filled fields:

```text
early: 0%–33%
middle: 34%–66%
late: 67%–100%
```

Each phase can have multipliers rather than a completely independent weight
set. This keeps the search space manageable:

- Chance cost multiplier;
- Pijol risk multiplier;
- school progress multiplier;
- figure aggression multiplier;
- column protection multiplier.

Early game should generally preserve future options. Middle game should balance
bonuses and immediate score. Late game should prioritize reliable points and
completion because there are fewer future turns available.

The exact behavior should be verified through simulation instead of assumed in
advance.

## Diagnostics required for every tuning run

Average score alone is not enough to explain why a candidate wins or loses.
Every report should include:

- score distribution and confidence interval;
- school raw score;
- school bonus total;
- figure score;
- Pijol count and average Pijol loss;
- perfect-column bonus count;
- figures scored from hand;
- average number of rolls per game;
- average number of turns ending after each roll count;
- number of available scoring options at decision time;
- number of rerolled dice;
- number of turns spent chasing high-value figures.

These metrics make it possible to identify whether a candidate improves by
protecting columns, finding more figures from hand, avoiding Pijols, or simply
taking more immediate points.

## Limited rollouts as a later phase

If phase-aware weights and policy parameters are still insufficient, add
limited rollouts for difficult decisions.

The rollout evaluator should not explore the entire game tree. It should:

1. obtain the top 3–5 actions from the exact Advisor;
2. simulate a small number of future continuations for each action;
3. evaluate the estimated final game score;
4. use the rollout result only when the top actions are close.

An initial configuration could be:

- top 4 candidate actions;
- 10–20 sampled continuations per action;
- a horizon of 2–3 future turns;
- rollouts enabled only in the late game or on close decisions.

This will be slower than the current Advisor, so it should first be used only
offline during tuning. A cached or selectively triggered version could later be
considered for the UI.

## Suggested experiment sequence

Run experiments in this order:

1. Measure the current exact, greedy, and fast baselines.
2. Use the fast strategy to explore a larger candidate population.
3. Re-evaluate the best candidates with the exact Advisor.
4. Add phase multipliers to the existing weights.
5. Add stop/continue and reroll policy parameters.
6. Run multi-start optimization over weights and policy parameters.
7. Analyze diagnostics to identify the largest source of lost points.
8. Add limited rollouts only for the remaining high-impact decisions.
9. Validate the final candidate on a fresh seed range before adoption.

## Acceptance criteria

A new profile should be accepted only when all of the following are true:

- it is evaluated with the exact Advisor;
- it improves the shared holdout mean against the current production profile;
- the improvement is not explained by one unusually lucky seed range;
- a fresh adoption test remains positive;
- the confidence interval is sufficiently narrow for the intended decision;
- no important diagnostic metric regresses unexpectedly;
- the profile and its seeds are saved as reproducible artifacts.

The 1800-point target should therefore be treated as a staged research target:
first establish whether the current policy family can approach it, then expand
the policy only where the diagnostics show a real limitation.
