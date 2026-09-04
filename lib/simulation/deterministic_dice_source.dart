import '../domain/game_engine.dart';

/// Produces a stable die value for every game turn, roll and die position.
///
/// Decisions made by a strategy do not shift the random stream. This lets two
/// strategies face the same potential rolls even when they reroll different
/// dice or finish turns at different moments.
class DeterministicDiceSource {
  final int seed;

  const DeterministicDiceSource(this.seed);

  DiceRoll firstRoll(int turnIndex) => DiceRoll([
    for (var dieIndex = 0; dieIndex < DICE_COUNT; dieIndex++)
      valueAt(turnIndex: turnIndex, rollIndex: 0, dieIndex: dieIndex),
  ]);

  DiceRoll reroll({
    required DiceRoll current,
    required int turnIndex,
    required int rollIndex,
    required Iterable<int> dieIndices,
  }) {
    if (rollIndex < 1 || rollIndex > 2) {
      throw ArgumentError.value(
        rollIndex,
        'rollIndex',
        'A reroll index must be 1 or 2.',
      );
    }
    final indices = dieIndices.toSet();
    if (indices.length != dieIndices.length ||
        indices.any((index) => index < 0 || index >= DICE_COUNT)) {
      throw ArgumentError.value(
        dieIndices,
        'dieIndices',
        'Rerolled die indices must be unique and between 0 and 5.',
      );
    }
    return DiceRoll([
      for (var dieIndex = 0; dieIndex < DICE_COUNT; dieIndex++)
        if (indices.contains(dieIndex))
          valueAt(
            turnIndex: turnIndex,
            rollIndex: rollIndex,
            dieIndex: dieIndex,
          )
        else
          current.values[dieIndex],
    ]);
  }

  int valueAt({
    required int turnIndex,
    required int rollIndex,
    required int dieIndex,
  }) {
    if (turnIndex < 0 || rollIndex < 0 || dieIndex < 0) {
      throw ArgumentError('Roll coordinates cannot be negative.');
    }
    var value = _mix32(seed);
    value = _mix32(value ^ _mix32(turnIndex + 0x9e3779b9));
    value = _mix32(value ^ _mix32(rollIndex + 0x85ebca6b));
    value = _mix32(value ^ _mix32(dieIndex + 0xc2b2ae35));
    return value % MAX_DIE_VALUE + MIN_DIE_VALUE;
  }
}

int _mix32(int input) {
  var value = input & 0xffffffff;
  value = ((value ^ (value >>> 16)) * 0x7feb352d) & 0xffffffff;
  value = ((value ^ (value >>> 15)) * 0x846ca68b) & 0xffffffff;
  return (value ^ (value >>> 16)) & 0xffffffff;
}
