# OptimalRoll Rules - Specification

## 1. Goal of the Game

The goal of the game is to score as many points as possible by filling in the
player scorecard with results obtained from rolling six dice.

Each player has **3 independent scoring columns**. Each column consists of:

1. **the school section** - 6 fields corresponding to die face values from 1 to 6,
2. **the figures section** - a set of dice combinations described later in this
   document.

The same scoring field appears separately in each of the 3 columns, so during
the whole game a player can record a given figure type at most three times -
once in each column.

The player with the highest final score wins.

------------------------------------------------------------------------

## 2. Dice and Turn Flow

The game uses **6 standard six-sided dice (d6)** with values from 1 to 6.

On their turn, a player may roll at most **3 times**.

### 2.1. First Roll

The first roll is made with all 6 dice.

### 2.2. Second and Third Roll

After each roll, the player may:

- keep any number of dice,
- reroll the remaining dice,
- change which dice are kept before the next roll.

The player does not have to use all 3 rolls. They may end their turn earlier if
the current dice combination is satisfactory.

After rolling is finished, the turn result must be recorded in one legal,
empty field on the player's scorecard.

------------------------------------------------------------------------

# 3. Player Scorecard Structure

Each player has **3 columns**:

- Column 1,
- Column 2,
- Column 3.

Each column contains its own school section and its own complete set of figures.

Layout:

```text
                 COLUMN 1   COLUMN 2   COLUMN 3

SCHOOL
1
2
3
4
5
6
School sum
School bonus

FIGURES
Pair
Two pairs
Three of a kind
Four of a kind
General
Marshal
Three pairs
Two triples
Four + two
Small straight
Big straight
Great straight
Even
Odd
Full house
Small
Chance

Bonus for a column without a pijol
Column total
```

Each field may be used only once.

------------------------------------------------------------------------

# 4. School Section

The school section is located above the figures section in **each of the three
columns**.

It contains 6 rows:

- 1,
- 2,
- 3,
- 4,
- 5,
- 6.

The row indicates the die face value for which the score is calculated.

## 4.1. Basic Rule

For a value `X`, the neutral result is **3 dice showing value X**.

Each die above three adds `X` points.

Each missing die below three subtracts `X` points.

Formally:

```text
school_points = (number_of_dice_X - 3) * X
```

where:

- `X` = the analyzed die face value, from 1 to 6,
- `number_of_dice_X` = the number of dice showing X.

## 4.2. School Scoring Table

For any X:

```text
Number of dice X   Score
---------------- -------
               0     -3X
               1     -2X
               2      -X
               3       0
               4      +X
               5     +2X
               6     +3X
```

### Example for Threes

```text
Number of threes   Points
---------------- --------
               0       -9
               1       -6
               2       -3
               3        0
               4       +3
               5       +6
               6       +9
```

### Example for Sixes

```text
Number of sixes   Points
--------------- --------
              0      -18
              1      -12
              2       -6
              3        0
              4       +6
              5      +12
              6      +18
```

Example: a roll containing four fours allows the player to enter **+4** in an
empty `4` row field in the chosen column.

------------------------------------------------------------------------

# 5. Opening a Figures Column

At the start of the game, the figures section of each column is **closed**.

To open the figures section in a specific column, the player must have at least
**3 filled fields** in that column's school section.

The values of those fields do not matter:

- positive,
- equal to 0,
- negative.

Only the fact that three school fields in that column have already been used
matters.

Example:

```text
1: empty
2: -2
3: empty
4: +4
5: -10
6: empty
```

This column has 3 entries, so its figures section is open.

Opening one column **does not open the other columns**.

------------------------------------------------------------------------

# 6. School Bonus

After the school section is filled, its six base results are summed.

Let `S` be the raw school point sum.

Bonus:

```text
Sum S                                                            Bonus
----- ---------------------------------------------------------------
S <= 10                                                               0
11-20                                                              +50
21-30                                                             +100
31-40                                                             +150
41-50                                                             +200
etc.        another +50 for each next started interval of 10 points
```

In other words, the first bonus appears at 11 points, then increases by 50
points after crossing each next multiple of 10.

Examples:

```text
S = 8  -> bonus 0
S = 10 -> bonus 0
S = 11 -> bonus 50
S = 20 -> bonus 50
S = 21 -> bonus 100
S = 30 -> bonus 100
S = 31 -> bonus 150
```

The final school score for a column is:

```text
school_score = raw_school_sum + school_bonus
```

------------------------------------------------------------------------

# 7. Figures

A figure may be entered only in an **open column** and only if the corresponding
field in that column is still empty.

## 7.1. Pair

Two dice of the same value.

Example:

```text
4, 4
```

The figure value is the sum of the dice belonging to the figure.

Example:

```text
4 + 4 = 8 points
```

## 7.2. Two Pairs

Two different pairs.

Example:

```text
2, 2, 5, 5
```

Points:

```text
2 + 2 + 5 + 5 = 14
```

## 7.3. Three of a Kind

Three dice of the same value.

Example:

```text
5, 5, 5
```

Points:

```text
15
```

## 7.4. Four of a Kind

Four dice of the same value.

Example:

```text
6, 6, 6, 6
```

Points:

```text
24
```

## 7.5. General

Five dice of the same value.

The value of a General is equal to half the value of the corresponding Marshal.

For a General with value X:

```text
points = (100 + 10 * X) / 2
```

which means:

```text
points = 50 + 5 * X
```

Table:

```text
General        Points
------------- -------
five ones          55
five twos          60
five threes        65
five fours         70
five fives         75
five sixes         80
```

## 7.6. Marshal

Six dice of the same value.

For a Marshal with value X:

```text
points = 100 + 10 * X
```

Table:

```text
Marshal        Points
------------- -------
six ones          110
six twos          120
six threes        130
six fours         140
six fives         150
six sixes         160
```

## 7.7. Three Pairs

Six dice forming three pairs.

Example:

```text
1, 1, 3, 3, 6, 6
```

The figure value is the sum of all 6 dice:

```text
1 + 1 + 3 + 3 + 6 + 6 = 20
```

## 7.8. Two Triples

Six dice forming two groups of three identical values.

Example:

```text
3, 3, 3, 4, 4, 4
```

Points:

```text
3 + 3 + 3 + 4 + 4 + 4 = 21
```

## 7.9. Four + Two

Six dice consisting of:

- four identical dice,
- two identical dice of a different value.

Example:

```text
5, 5, 5, 5, 2, 2
```

Points:

```text
5 + 5 + 5 + 5 + 2 + 2 = 24
```

------------------------------------------------------------------------

# 8. Straights

## 8.1. Small Straight

Required values:

```text
1, 2, 3, 4, 5
```

Points:

```text
15
```

The sixth die is not part of the Small Straight and does not increase its value.

## 8.2. Big Straight

Required values:

```text
2, 3, 4, 5, 6
```

Points:

```text
20
```

The sixth die is not part of the Big Straight and does not increase its value.

## 8.3. Great Straight

The exact required set of six values:

```text
1, 2, 3, 4, 5, 6
```

Points:

```text
35
```

------------------------------------------------------------------------

# 9. Even

The figure requires **6 dice with even values**.

Allowed values:

```text
2, 4, 6
```

Each of the six dice must be even.

The figure value is the sum of all dice.

Example:

```text
2, 2, 4, 4, 6, 6
```

Points:

```text
24
```

------------------------------------------------------------------------

# 10. Odd

The figure requires **6 dice with odd values**.

Allowed values:

```text
1, 3, 5
```

Each of the six dice must be odd.

The figure value is the sum of all dice.

Example:

```text
1, 1, 3, 3, 5, 5
```

Points:

```text
18
```

------------------------------------------------------------------------

# 11. Full House

A Full House consists of:

- three identical dice,
- two other identical dice.

This is a `3 + 2` combination.

Because 5 dice are used, the sixth die is not part of the Full House.

Example:

```text
2, 2, 2, 5, 5, 6
```

The figure is formed by:

```text
2, 2, 2, 5, 5
```

Points:

```text
2 + 2 + 2 + 5 + 5 = 16
```

------------------------------------------------------------------------

# 12. Small

The **Small** figure is available if **the sum of all 6 dice is less than or
equal to 10**.

Let:

```text
S = sum of all 6 dice
```

Condition:

```text
S <= 10
```

Scoring:

```text
points = (10 - S) * 10 + S
```

This can also be written as:

```text
points = 100 - 9S
```

Example 1:

```text
Dice: 1, 1, 1, 1, 2, 3
S = 9

points = (10 - 9) * 10 + 9
points = 19
```

Example 2:

```text
Dice: 1, 1, 1, 1, 2, 2
S = 8

points = (10 - 8) * 10 + 8
points = 28
```

The lower the dice sum, the more points the figure gives.

------------------------------------------------------------------------

# 13. Chance

Chance does not require any specific combination.

Any final roll may be entered as Chance, as long as the Chance field in the
chosen open column is empty.

Points are the sum of all 6 dice.

Example:

```text
1, 2, 3, 3, 5, 6
```

Points:

```text
20
```

Chance acts as an emergency field when the result is not suitable for a more
valuable figure.

------------------------------------------------------------------------

# 14. Pijol

If, after finishing the rolls, the player does not have a figure they can or
want to enter into an available field, they may use a **pijol**.

A pijol means permanently crossing out one selected figure field.

A crossed-out field:

- is worth **0 points**,
- is considered used,
- cannot receive a figure later.

A pijol also matters for the column completion bonus.

------------------------------------------------------------------------

# 15. Bonus for a Column Without a Pijol

If the player fills all figure fields in a given column **without using any
pijol in that column**, they receive:

```text
+100 points
```

If the column contains at least one pijol:

```text
bonus = 0
```

The bonus is calculated independently for each of the 3 columns.

Therefore, the maximum total bonus a player can receive is:

```text
3 * 100 = 300 points
```

for complete columns without pijols.

------------------------------------------------------------------------

# 16. Legal Score Entry After a Turn

After finishing the rolls, the player chooses one legal field.

Possible cases:

### School

The player may enter a school score into an empty field corresponding to the
analyzed die face value in one of the columns.

The figures section does not need to be open to enter scores into the school
section.

### Figure

The player may enter a figure only if:

1. the dice combination satisfies the figure requirements,
2. that figure field is empty in the chosen column,
3. the figures section of that column is open, meaning its school section has
   at least 3 entries.

### Chance

Chance works like a normal figure, but it has no dice combination requirements.

### Pijol

If the player cannot use the roll in a satisfactory way, they may cross out an
empty figure field, effectively recording 0 points in it.

------------------------------------------------------------------------

# 17. Satisfying Multiple Figures at Once

The same dice combination may satisfy the requirements of more than one figure.

Example:

```text
2, 2, 2, 2, 5, 5
```

The combination may be treated as, among others:

- pair,
- two pairs,
- three of a kind,
- four of a kind,
- four + two,
- chance.

The player chooses the field, also depending on which fields are still available
in open columns.

For figures that use fewer than 6 dice, only the dice belonging to the selected
figure are counted for scoring.

------------------------------------------------------------------------

# 18. End of the Game

The game ends after all required fields on the player scorecards have been
filled.

For each of the 3 columns, calculate:

1. the raw school sum,
2. the school bonus,
3. points from all figures,
4. the optional +100 bonus for a figures column without a pijol.

Then sum the results of all three columns.

```text
player_score =
    column_1_score
  + column_2_score
  + column_3_score
```

The player with the highest number of points wins.

------------------------------------------------------------------------

# 19. Implementation-Oriented Formalization

## 19.1. Single Column State

A column should store at least:

```text
school:
  ones: value | empty
  twos: value | empty
  threes: value | empty
  fours: value | empty
  fives: value | empty
  sixes: value | empty

figures:
  pair: value | empty | pijol
  twoPairs: value | empty | pijol
  three: value | empty | pijol
  four: value | empty | pijol
  general: value | empty | pijol
  marshal: value | empty | pijol
  threePairs: value | empty | pijol
  twoThrees: value | empty | pijol
  fourPlusTwo: value | empty | pijol
  smallStraight: value | empty | pijol
  bigStraight: value | empty | pijol
  greatStraight: value | empty | pijol
  even: value | empty | pijol
  odd: value | empty | pijol
  full: value | empty | pijol
  small: value | empty | pijol
  chance: value | empty | pijol
```

## 19.2. Column Opening Condition

```text
column.isOpen =
    number_of_filled_fields_in_school >= 3
```

## 19.3. School Scoring

For value X:

```text
schoolScore(X, countX) = (countX - 3) * X
```

## 19.4. General Scoring

```text
generalScore(X) = 50 + 5 * X
```

## 19.5. Marshal Scoring

```text
marshalScore(X) = 100 + 10 * X
```

## 19.6. Small Scoring

```text
if sum(dice) <= 10:
    smallScore = (10 - sum(dice)) * 10 + sum(dice)
else:
    figure unavailable
```

## 19.7. Chance

```text
chanceScore = sum(dice)
```

## 19.8. Pijol

```text
pijolScore = 0
```

and:

```text
columnPerfectBonus = 0
```

if at least one pijol was used in that column.

------------------------------------------------------------------------

# 20. Important Assumptions for the Move Suggestion Algorithm

The algorithm that analyzes the best move should receive at least:

```text
- current values of the 6 dice,
- number of rolls remaining in the turn,
- school state in all 3 columns,
- figures state in all 3 columns,
- information about pijols,
- information about which columns are open.
```

The algorithm should not choose a move based only on points available in the
current turn.

It should also account for the strategic value of the move, for example:

- probability of obtaining a figure after subsequent rolls,
- expected value of each decision about keeping dice,
- field availability in each column,
- ability to open a new column by entering a school score,
- value of the school bonus,
- risk of losing the +100 bonus by having to use a pijol,
- future value of leaving specific fields empty,
- ability to use one roll as several different figures.

This allows the game logic to be separated from the user interface and reused in
the future by the mobile application, as well as by modules for recognizing dice
and the scorecard from an image.
