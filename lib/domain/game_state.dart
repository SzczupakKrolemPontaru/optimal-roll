import 'dart:collection';

import 'constants.dart';
import 'figures.dart';

class ScoreEntry {
  final FieldStatus status;
  final int? points;

  const ScoreEntry.empty() : status = FieldStatus.EMPTY, points = null;

  const ScoreEntry.scored(this.points) : status = FieldStatus.SCORED;

  const ScoreEntry.pijol() : status = FieldStatus.PIJOL, points = 0;
}

class ScoreColumn {
  final Map<int, ScoreEntry> school;
  final Map<Figure, ScoreEntry> figures;

  ScoreColumn({Map<int, ScoreEntry>? school, Map<Figure, ScoreEntry>? figures})
    : school = _IndexedScoreMap<int>(
        keys: [for (var i = MIN_DIE_VALUE; i <= MAX_DIE_VALUE; i++) i],
        indexOf: (face) => face - MIN_DIE_VALUE,
        initial: school,
      ),
      figures = _IndexedScoreMap<Figure>(
        keys: Figure.values,
        indexOf: (figure) => figure.index,
        initial: figures,
      );

  ScoreColumn._fromMaps(this.school, this.figures);

  bool get isOpen =>
      school.values.where((e) => e.status != FieldStatus.EMPTY).length >=
      SCHOOL_NEUTRAL_COUNT;

  bool get hasPijol => figures.values.any((e) => e.status == FieldStatus.PIJOL);

  bool get isComplete =>
      school.values.every((entry) => entry.status != FieldStatus.EMPTY) &&
      figures.values.every((entry) => entry.status != FieldStatus.EMPTY);

  int get rawSchoolScore =>
      school.values.fold(0, (sum, e) => sum + (e.points ?? 0));

  int get schoolBonus => rawSchoolScore <= SCHOOL_BONUS_THRESHOLD
      ? 0
      : ((rawSchoolScore - 1) ~/ SCHOOL_BONUS_THRESHOLD) * SCHOOL_BONUS_POINTS;

  int get perfectColumnBonus =>
      !hasPijol &&
          figures.values.every((entry) => entry.status != FieldStatus.EMPTY)
      ? PERFECT_COLUMN_BONUS
      : 0;

  int get total =>
      rawSchoolScore +
      schoolBonus +
      figures.values.fold<int>(0, (sum, e) => sum + (e.points ?? 0)) +
      perfectColumnBonus;

  ScoreColumn copy() => ScoreColumn._fromMaps(
    (school as _IndexedScoreMap<int>).copy(),
    (figures as _IndexedScoreMap<Figure>).copy(),
  );
}

class GameState {
  final List<ScoreColumn> columns;

  GameState(this.columns) {
    if (columns.length != 3) {
      throw ArgumentError('There must be three columns.');
    }
  }

  GameState copy() =>
      GameState(columns.map((column) => column.copy()).toList());

  bool get isComplete => columns.every((column) => column.isComplete);

  int get total => columns.fold(0, (sum, column) => sum + column.total);
}

/// Fixed-key map used by scorecards.
///
/// Scorecard fields are never added or removed: every school face and every
/// figure exists from the start and only its [ScoreEntry] changes. A small
/// indexed array is therefore cheaper to copy and access than a hash map,
/// while retaining the Map API used by the UI and simulation code.
class _IndexedScoreMap<K> extends MapBase<K, ScoreEntry> {
  final List<K> _keys;
  final int Function(K key) _indexOf;
  final List<ScoreEntry> _values;

  _IndexedScoreMap({
    required List<K> keys,
    required this._indexOf,
    Map<K, ScoreEntry>? initial,
  }) : _keys = List.unmodifiable(keys),
       _values = [
         for (var index = 0; index < keys.length; index++)
           initial?[keys[index]] ?? const ScoreEntry.empty(),
       ];

  _IndexedScoreMap._copy(this._keys, this._indexOf, this._values);

  _IndexedScoreMap<K> copy() =>
      _IndexedScoreMap._copy(_keys, _indexOf, List<ScoreEntry>.from(_values));

  @override
  Iterable<K> get keys => _keys;

  @override
  ScoreEntry? operator [](Object? key) {
    if (key is! K) return null;
    final index = _indexOf(key);
    if (index < 0 || index >= _values.length || _keys[index] != key) {
      return null;
    }
    return _values[index];
  }

  @override
  void operator []=(K key, ScoreEntry value) {
    final index = _indexOf(key);
    if (index < 0 || index >= _values.length || _keys[index] != key) {
      throw ArgumentError.value(key, 'key', 'Unknown scorecard key.');
    }
    _values[index] = value;
  }

  @override
  ScoreEntry? remove(Object? key) {
    if (key is! K) return null;
    final index = _indexOf(key);
    if (index < 0 || index >= _values.length || _keys[index] != key) {
      return null;
    }
    final previous = _values[index];
    _values[index] = const ScoreEntry.empty();
    return previous;
  }

  @override
  void clear() {
    for (var index = 0; index < _values.length; index++) {
      _values[index] = const ScoreEntry.empty();
    }
  }
}
