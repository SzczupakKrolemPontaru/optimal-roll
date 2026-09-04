import 'constants.dart';

class DiceRoll {
  final List<int> values;

  DiceRoll(Iterable<int> values) : values = List.unmodifiable(values) {
    if (this.values.length != DICE_COUNT ||
        this.values.any((v) => v < MIN_DIE_VALUE || v > MAX_DIE_VALUE)) {
      throw ArgumentError('A roll must contain six values from 1 to 6.');
    }
  }

  late final List<int> counts = List.unmodifiable([
    for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++)
      values.where((v) => v == face).length,
  ]);

  late final int sum = values.fold(0, (sum, value) => sum + value);
}
