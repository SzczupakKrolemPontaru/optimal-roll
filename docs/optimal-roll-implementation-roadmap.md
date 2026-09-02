# OptimalRoll — Implementation Roadmap

## 1. Project Goal

The application should recognize the current game state and recommend which
dice the player should keep and which dice they should reroll to improve their
chances of achieving a good score and ultimately winning the game.

The target data flow is:

```text
photo of the game area
    ↓
dice and scorecard recognition
    ↓
user review and correction
    ↓
game state
    ↓
strategy engine
    ↓
recommendation, e.g. "Keep 2, 2, 5, 5 — reroll the other two dice"
```

The project should be divided into three independent layers:

1. game rules engine,
2. strategy engine,
3. image recognition.

Image recognition is only a way of entering data, not the core of the
application. Therefore, it should not be implemented first.

## 2. Implementation Order

### Stage 1 — Game Rules Engine

The first component should be a UI-independent rules engine. It should accept
plain Dart data and know nothing about Flutter, the camera, or how results are
presented.

An example directory structure:

```text
lib/
  domain/
    dice.dart
    score_field.dart
    score_entry.dart
    score_column.dart
    game_state.dart
  rules/
    figure_evaluator.dart
    legal_moves.dart
    score_calculator.dart
```

The following should be implemented:

- representation of six dice,
- representation of the three scorecard columns,
- field states: `empty`, `scored`, and `pijol`,
- checking whether a figures column is open,
- detection of every figure,
- score calculation,
- determination of every legal scoring option,
- school bonus calculation,
- bonus for completing a column without a pijol.

An example API:

```dart
List<ScoringOption> findLegalScoringOptions(
  DiceRoll dice,
  GameState game,
);
```

For the following dice:

```text
2, 2, 2, 2, 5, 5
```

the engine should detect, among other options:

- pair,
- two pairs,
- three of a kind,
- four of a kind,
- four plus two,
- chance,
- the corresponding school entries.

This stage should have extensive unit test coverage. An error in the rules may
later appear to be an error in the strategy algorithm.

### Stage 2 — Application with Manual Data Entry

The next step should be a simple interface that allows the user to:

- set the values of all six dice,
- provide the number of rolls remaining,
- enter the state of all three scorecard columns,
- mark occupied fields and pijols,
- see every available scoring option and its score.

At this stage, the application does not need to select which dice should be
rerolled. It should correctly answer the following question:

> What can I legally score with the current dice?

Manual input will make it possible to test the rules and strategy independently
of image recognition accuracy.

### Stage 3 — Advisor for One Remaining Roll

The first version of the strategy engine should solve a limited problem:

> Which dice should be kept to obtain the highest expected score in this turn?

There are only 64 possible keep masks for six dice:

```text
2^6 = 64
```

For each decision, every possible result of the next roll can be analyzed
exactly. If `n` dice are rerolled, there are:

```text
6^n
```

possible outcomes. In the largest case, this is only:

```text
6^6 = 46,656
```

Artificial intelligence or machine learning is not required here. Exact
probability and expected-value calculations can be used.

The recommendation should be understandable to the user, for example:

```text
Keep: 2, 2, 5, 5
Reroll: 1, 4
Best target: Two pairs / Three pairs
Estimated move value: 18.4 points
```

### Stage 4 — Strategy for Two Remaining Rolls

The algorithm should then account for both the second and third rolls. Dynamic
programming can be used with a function such as:

```text
value(dice, rollsLeft, gameState)
```

For each keep mask, the algorithm:

1. generates the possible reroll outcomes,
2. calculates the probability of each outcome,
3. selects the best decision again for every outcome,
4. returns the decision with the highest expected value.

Memoization should be used. A dice roll can be represented as counts:

```text
[number of ones, number of twos, ..., number of sixes]
```

This makes different orderings of the same dice equivalent to a single state.

### Stage 5 — Whole-Game Strategy

Optimizing the entire game is more difficult than choosing the best result in
a single turn. Scoring the most points now does not always produce the best
decision.

In the future, the algorithm should account for factors including:

- the ability to open a column by recording a school score,
- changes in the probability of receiving a school bonus,
- the cost of consuming a Chance field,
- the future usefulness of fields that remain empty,
- the risk of a pijol and losing the `+100` bonus,
- the rarity of particular figures,
- the ability to use one dice combination as several different figures.

The first version can use a heuristic entry value:

```text
value =
    points scored
  + change in expected school bonus
  + value of opening a column
  - cost of consuming a valuable field
  - future pijol risk
```

An exact solution for the entire game has a very large state space. Possible
later approaches include:

- Monte Carlo simulations,
- Monte Carlo Tree Search,
- a value function trained on simulated games,
- a combination of exact current-turn calculations and a future-value
  heuristic.

The project should not begin with a neural network. It first needs a correct
simulator that can generate data and measure the quality of different
strategies.

### Stage 6 — Dice Recognition from an Image

Dice are easier to recognize than an entire scorecard, so they should be the
first component of the image-processing layer.

```text
photo
→ detect six dice
→ detect pips
→ determine values from 1 to 6
→ confirmation screen
```

The first version may require:

- a top-down view of the dice,
- good lighting,
- a uniform background,
- no overlapping dice.

The user must be able to correct every recognized value. One incorrectly
recognized die can completely change the recommendation.

### Stage 7 — Scorecard Recognition from an Image

Recognizing the scorecard will probably be the most difficult part of the image
layer. The system must recognize:

- the position of the sheet,
- image perspective,
- individual cells,
- handwritten numbers,
- empty fields,
- crossed-out fields representing pijols.

If the scorecard always uses the same printed template, the process can be
simplified:

```text
detect corners
→ correct perspective
→ divide the image according to a fixed template
→ classify the contents of each cell
```

The recognized scorecard state should always be presented to the user for
confirmation or correction.

## 3. Proposed Milestones

1. **Rules MVP** — all combinations and scoring rules are implemented and
   covered by tests.
2. **Manual MVP** — the user manually enters the dice and scorecard state, and
   the application displays legal scoring options.
3. **Turn Advisor** — the application recommends which dice to keep with one
   roll remaining.
4. **Full Turn Advisor** — the application recommends a move with one or two
   rolls remaining.
5. **Game Strategy** — recommendations account for the effect of a move on the
   rest of the game.
6. **Dice Camera** — the application recognizes dice and allows the result to
   be corrected.
7. **Scorecard Camera** — the application recognizes the scorecard and allows
   it to be corrected.
8. **Validation** — strategies are compared across thousands of simulated
   games.

## 4. First Implementation Goal

The first concrete project goal is:

> The user manually sets the six dice and the scorecard state, and the
> application correctly displays every legal field and the number of points
> that can be scored in each one.

The second goal is:

> The application indicates which dice should be kept when one roll remains.

This order makes it possible to build a working product quickly without making
the rules or strategy engine dependent on inaccurate image recognition.

## 5. First MVP Completion Criteria

The first stage can be considered complete when:

- all figures described in the specification are detected correctly,
- school scores and bonuses are calculated correctly,
- occupied fields are not suggested again,
- figures are not suggested in closed columns,
- pijols affect the bonus for completing a column,
- one dice combination can return multiple valid scoring options,
- edge cases have unit tests,
- the logic can run without the Flutter interface.

The source of truth for the rules remains
[`optimal-roll-game-rules.md`](optimal-roll-game-rules.md).
