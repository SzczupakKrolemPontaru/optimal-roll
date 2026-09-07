import 'dart:math' show max;

import '../domain/game_engine.dart';
import 'advisor_action.dart';

/// Compact feature model for an already-scored game state.
///
/// The coefficients are deliberately kept separate from the advisor weights:
/// they are trained offline from complete games and only evaluated during a
/// decision. A zero model is equivalent to not using state-value guidance.
class StateValueModel {
  final List<double> coefficients;
  final double intercept;

  const StateValueModel({required this.coefficients, this.intercept = 0});

  const StateValueModel.zero()
    : coefficients = const [0, 0, 0, 0, 0, 0],
      intercept = 0;

  /// Coefficients trained by [tool/train_state_value_model.dart] on 500
  /// complete games. Keep the model opt-in until it proves useful on holdout
  /// seeds.
  static const trained = StateValueModel(
    coefficients: [
      272.04692434069887,
      374.7658742964312,
      261.34179042104324,
      507.10197667141887,
      87.6448686946794,
      261.5601404185311,
    ],
    intercept: 636.1076647174679,
  );

  double evaluate(GameState game) {
    final features = stateValueFeatures(game);
    var value = intercept;
    for (var index = 0; index < features.length; index++) {
      value += coefficients[index] * features[index];
    }
    return value;
  }
}

/// Offline action-value model. The label is the final game score obtained
/// after taking a concrete legal option from a concrete state.
class ActionValueModel {
  final List<double> coefficients;
  final double intercept;

  const ActionValueModel({required this.coefficients, this.intercept = 0});

  static const trained200 = ActionValueModel(
    coefficients: [
      0,
      0,
      387.99501457356763,
      387.99501457356763,
      0,
      387.99501457356763,
      12.498783845085567,
      0,
      46.31947268585821,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ],
    intercept: 387.99501457356763,
  );

  double evaluate(GameState game, ScoringOption option) {
    final features = stateActionFeatures(game, option);
    var value = intercept;
    for (var index = 0; index < features.length; index++) {
      value += coefficients[index] * features[index];
    }
    return value;
  }
}

class PhasedActionValueModel {
  final ActionValueModel early;
  final ActionValueModel middle;
  final ActionValueModel late;

  const PhasedActionValueModel({
    required this.early,
    required this.middle,
    required this.late,
  });

  ActionValueModel forState(GameState game) {
    final progress = stateValueFeatures(game)[1];
    if (progress < 1 / 3) return early;
    if (progress < 2 / 3) return middle;
    return late;
  }

  double evaluate(GameState game, ScoringOption option) =>
      forState(game).evaluate(game, option);

  static const trained200 = PhasedActionValueModel(
    early: ActionValueModel.trained200,
    middle: ActionValueModel.trained200,
    late: ActionValueModel.trained200,
  );

  static const trainedPhased500 = PhasedActionValueModel(
    early: ActionValueModel(
      intercept: 321.324497017062,
      coefficients: [
        0,
        0,
        321.324497017062,
        321.324497017062,
        0,
        321.324497017062,
        -2.591292171856874,
        0,
        23.053734811814493,
        0,
        0,
        0,
        321.324497017062,
        73.23127358487851,
        0,
        0,
        0,
      ],
    ),
    middle: ActionValueModel(
      intercept: 465.87151920872356,
      coefficients: [
        186.28657946295425,
        155.29050640290822,
        310.5810128058165,
        465.87151920872356,
        2.0768738949698133,
        308.6293896412724,
        80.78261682159174,
        168.96982946776436,
        42.99385166097847,
        63.03684838655718,
        -34.841863149330685,
        -63.380720563463925,
        64.5511397097302,
        30.148407357684622,
        -11.670473600551587,
        31.917184012601115,
        38.60625512197124,
      ],
    ),
    late: ActionValueModel(
      intercept: 456.232023566676,
      coefficients: [
        374.59686323648424,
        304.1546823777853,
        152.07734118889272,
        488.14089688017674,
        170.85536060664674,
        150.15496424657624,
        96.18603585533513,
        162.62423730853587,
        38.08129518325538,
        152.8028056061646,
        37.663903785109156,
        -82.28258555733699,
        48.70096339226835,
        29.743206763855348,
        2.607044073263298,
        -35.58786722506739,
        -24.833430388758273,
      ],
    ),
  );

  /*
  static const trainedRank50 = PhasedActionValueModel(
    early: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .06319394976547729,
        0,
        -.23921460040411566,
        0,
        0,
        0,
        0,
        -.10533929171474296,
        0,
        0,
        0,
      ],
    ),
    middle: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .28665919326816425,
        -.09136925144518296,
        .0984023291566554,
        .05345911432729952,
        .532739724378162,
        -.3928647890124259,
        -.21012628612206005,
        -.11523171759092944,
        .42575133174531216,
        -.054396902107439395,
        -.04737632537144432,
      ],
    ),
    late: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .2561908560356086,
        -.24066605103024694,
        -.06014137492222702,
        -.02557478928023655,
        .3181819361980482,
        -.6118095394419465,
        -.13047743738145312,
        -.04002875761278923,
        -.054339390134511625,
        -.14183907176970192,
        -.10925316872925832,
      ],
    ),
  );
  */

  static const trainedRankClose50 = PhasedActionValueModel(
    early: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .060453544246440824,
        0,
        -.08512219974909294,
        0,
        0,
        0,
        0,
        -.16865314435205275,
        0,
        0,
        0,
      ],
    ),
    middle: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .2852777211912171,
        .18719608943425975,
        -.026846325769102876,
        .0011054522537646211,
        -.028945945346261007,
        0,
        -.3743921788685195,
        -.11211781994976179,
        .2999396980479002,
        .12652484875591144,
        .21841020070580824,
      ],
    ),
    late: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .25594059326555313,
        -.2532354392361336,
        -.20476011953123155,
        -.034231733864101554,
        .12531439606269254,
        -.6325906195334191,
        -.12611974106115215,
        -.025531294393013947,
        -.050596312527913,
        -.13046947453655966,
        .07804179968686586,
      ],
    ),
  );
}

class RerollValueModel {
  final List<double> coefficients;
  final double intercept;

  const RerollValueModel({required this.coefficients, this.intercept = 0});

  static const trained500 = RerollValueModel(
    intercept: 287.3793483727316,
    coefficients: [
      -.009023911301966126,
      -.04229188389406198,
      287.42164025662566,
      287.3793483727316,
      0,
      287.3793483727316,
      169.12376572338087,
      118.25558264935056,
      122.88143071306766,
      45.89437026967029,
      287.3793483727316,
      51.03035095116457,
      33.7873093283858,
      32.40697661142153,
    ],
  );

  double evaluate(GameState game, List<int> keptCounts, int rollsLeft) {
    final features = rerollCountFeatures(game, keptCounts, rollsLeft);
    var value = intercept;
    for (var index = 0; index < features.length; index++) {
      value += coefficients[index] * features[index];
    }
    return value;
  }

  double evaluateActionAdvantage(
    GameState game,
    List<int> keptCounts,
    int rollsLeft,
  ) {
    final features = rerollCountFeatures(game, keptCounts, rollsLeft);
    var value = 0.0;
    for (var index = stateValueFeatureCount; index < features.length; index++) {
      value += coefficients[index] * features[index];
    }
    return value;
  }
}

const stateValueFeatureCount = 6;
const actionValueFeatureCount = 17;
const rerollValueFeatureCount = 14;

/// Features are normalized to roughly [0, 1] so offline training remains
/// numerically stable and the model can be evaluated without allocations.
List<double> stateValueFeatures(GameState game) {
  var usedFields = 0;
  var totalFields = 0;
  var cleanColumns = 0;
  var nearPerfectColumns = 0;
  var schoolPotential = 0.0;
  var figurePotential = 0.0;

  for (final column in game.columns) {
    final emptyFigures = column.figures.values
        .where((entry) => entry.status == FieldStatus.EMPTY)
        .length;
    final emptySchool = column.school.values
        .where((entry) => entry.status == FieldStatus.EMPTY)
        .length;
    final columnUsed =
        column.school.values
            .where((entry) => entry.status != FieldStatus.EMPTY)
            .length +
        column.figures.values
            .where((entry) => entry.status != FieldStatus.EMPTY)
            .length;
    usedFields += columnUsed;
    totalFields += column.school.length + column.figures.length;
    if (!column.hasPijol) cleanColumns++;
    if (!column.hasPijol && emptyFigures <= 2) nearPerfectColumns++;
    schoolPotential +=
        emptySchool * 3 +
        column.school.entries
            .where((entry) => entry.value.status == FieldStatus.EMPTY)
            .fold<double>(0, (sum, entry) => sum + entry.key / 6);
    figurePotential += emptyFigures * (cleanColumns > 0 ? 1 : .5);
  }

  final progress = totalFields == 0 ? 0.0 : usedFields / totalFields;
  return [
    game.total / 2500,
    progress,
    (1 - progress),
    (cleanColumns / game.columns.length).clamp(0.0, 1.0),
    (nearPerfectColumns / game.columns.length).clamp(0.0, 1.0),
    ((schoolPotential + figurePotential) / 100).clamp(0.0, 1.0),
  ];
}

List<double> stateActionFeatures(GameState game, ScoringOption option) {
  final state = stateValueFeatures(game);
  final column = game.columns[option.columnIndex];
  final usedColumn =
      column.school.values
          .where((entry) => entry.status != FieldStatus.EMPTY)
          .length +
      column.figures.values
          .where((entry) => entry.status != FieldStatus.EMPTY)
          .length;
  final totalColumn = column.school.length + column.figures.length;
  return [
    ...state,
    option.points / 100,
    option.type.index / 2,
    option.columnIndex / 2,
    usedColumn / totalColumn,
    option.figure == Figure.CHANCE ? 1 : 0,
    option.type == ScoringOptionType.pijol ? 1 : 0,
    option.type == ScoringOptionType.school ? 1 : 0,
    (option.schoolFace ?? 0) / 6,
    (option.figure?.index ?? 0) / (Figure.values.length - 1),
    _figurePotential(option.figure) / 160,
    _isStraight(option.figure) ? 1 : 0,
  ];
}

double _figurePotential(Figure? figure) => switch (figure) {
  Figure.PAIR => 12,
  Figure.TWO_PAIRS => 30,
  Figure.THREE_OF_A_KIND => 18,
  Figure.FOUR_OF_A_KIND => 24,
  Figure.GENERAL => 80,
  Figure.MARSHAL => 160,
  Figure.THREE_PAIRS => 30,
  Figure.TWO_TRIPLES => 30,
  Figure.FOUR_PLUS_TWO => 30,
  Figure.FULL_HOUSE => 30,
  Figure.SMALL_STRAIGHT => 30,
  Figure.BIG_STRAIGHT => 40,
  Figure.GREAT_STRAIGHT => 70,
  Figure.EVEN => 30,
  Figure.ODD => 30,
  Figure.SMALL => 28,
  Figure.CHANCE => 30,
  null => 0,
};

bool _isStraight(Figure? figure) => switch (figure) {
  Figure.SMALL_STRAIGHT || Figure.BIG_STRAIGHT || Figure.GREAT_STRAIGHT => true,
  _ => false,
};

List<double> rerollValueFeatures(
  GameState game,
  DiceRoll dice,
  RerollAdvisorAction action,
  int rollsLeft,
) {
  final kept = List<int>.filled(MAX_DIE_VALUE, 0);
  for (final index in action.keptDieIndices) {
    kept[dice.values[index] - MIN_DIE_VALUE]++;
  }
  return rerollCountFeatures(game, kept, rollsLeft);
}

List<double> rerollCountFeatures(
  GameState game,
  List<int> kept,
  int rollsLeft,
) {
  final state = stateValueFeatures(game);
  final keptCount = _sumCounts(kept);
  final distinct = kept.where((count) => count > 0).length;
  final largestGroup = kept.fold(0, (max, count) => count > max ? count : max);
  final smallStraight = _facesPresent(kept, 0, 4);
  final bigStraight = _facesPresent(kept, 1, 5);
  return [
    ...state,
    (DICE_COUNT - keptCount) / DICE_COUNT,
    keptCount / DICE_COUNT,
    largestGroup / DICE_COUNT,
    distinct / DICE_COUNT,
    rollsLeft / 2,
    max(smallStraight, bigStraight) / 5,
    _sumCounts(kept) / 21,
    kept.where((count) => count >= 2).length / MAX_DIE_VALUE,
  ];
}

int _facesPresent(List<int> counts, int first, int last) => [
  for (var index = first; index <= last; index++)
    if (counts[index] > 0) index,
].length;

int _sumCounts(List<int> counts) => counts.fold(0, (sum, count) => sum + count);
