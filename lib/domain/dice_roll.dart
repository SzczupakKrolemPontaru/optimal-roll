import 'constants.dart';

class DiceRoll {
  final List<int> values;
  late final List<int> counts;
  late final int sum;

  DiceRoll(Iterable<int> values) : values = List.unmodifiable(values) {
    if (this.values.length != DICE_COUNT ||
        this.values.any((v) => v < MIN_DIE_VALUE || v > MAX_DIE_VALUE)) {
      throw ArgumentError('A roll must contain six values from 1 to 6.');
    }
    final calculatedCounts = List.filled(MAX_DIE_VALUE, 0);
    var calculatedSum = 0;
    for (final value in this.values) {
      calculatedCounts[value - MIN_DIE_VALUE]++;
      calculatedSum += value;
    }
    counts = List.unmodifiable(calculatedCounts);
    sum = calculatedSum;
  }
}
