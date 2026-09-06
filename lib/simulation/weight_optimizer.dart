import 'dart:math';

import '../advisor/advisor.dart';
import '../domain/game_engine.dart';
import 'game_strategy.dart';
import 'simulation_report.dart';
import 'simulation_runner.dart';

enum PijolFigureGroup { basic, rare, compound, straight, parity, small, chance }

PijolFigureGroup pijolGroupFor(Figure figure) => switch (figure) {
  Figure.PAIR ||
  Figure.TWO_PAIRS ||
  Figure.THREE_OF_A_KIND ||
  Figure.FOUR_OF_A_KIND => PijolFigureGroup.basic,
  Figure.GENERAL || Figure.MARSHAL => PijolFigureGroup.rare,
  Figure.THREE_PAIRS ||
  Figure.TWO_TRIPLES ||
  Figure.FOUR_PLUS_TWO ||
  Figure.FULL_HOUSE => PijolFigureGroup.compound,
  Figure.SMALL_STRAIGHT ||
  Figure.BIG_STRAIGHT ||
  Figure.GREAT_STRAIGHT => PijolFigureGroup.straight,
  Figure.EVEN || Figure.ODD => PijolFigureGroup.parity,
  Figure.SMALL => PijolFigureGroup.small,
  Figure.CHANCE => PijolFigureGroup.chance,
};

class AdvisorWeightSearchSpace {
  final double openingColumnValueMax;
  final double chanceCostEarlyMax;
  final double chanceCostLateMax;
  final double rerollValueWeightMax;
  final double rerollValueWeightMin;
  final double rerollLowScoreWeightMax;
  final double pijolBaseCostMax;
  final double perfectColumnRiskCostMax;
  final double schoolBonusProgressWeightMax;
  final double schoolCompletionValueMax;
  final double pijolGroupCostMax;
  final double phaseRiskMultiplierMin;
  final double phaseRiskMultiplierMax;
  final double pijolScarcityWeightMax;
  final double figureOpportunityCostMin;
  final double figureOpportunityCostMax;
  final double schoolFaceOpportunityCostMax;
  final double schoolOpeningFaceCostMin;
  final double schoolOpeningFaceCostMax;
  final double schoolBonusTargetWeightMax;
  final double perfectColumnProgressWeightMax;
  final double schoolPointWeightMax;
  final double schoolNegativePenaltyWeightMax;
  final double figureCompletionValueWeightMax;
  final double rareFigureChaseWeightMax;
  final double straightChaseWeightMax;
  final double futureFieldValueWeightMax;
  final double figureSpecificOpportunityCostMax;
  final double figureSpecificOpportunityCostMin;

  const AdvisorWeightSearchSpace({
    required this.openingColumnValueMax,
    required this.chanceCostEarlyMax,
    required this.chanceCostLateMax,
    this.rerollValueWeightMax = 5,
    this.rerollValueWeightMin = 0,
    this.rerollLowScoreWeightMax = 10,
    required this.pijolBaseCostMax,
    required this.perfectColumnRiskCostMax,
    required this.schoolBonusProgressWeightMax,
    required this.schoolCompletionValueMax,
    required this.pijolGroupCostMax,
    this.phaseRiskMultiplierMin = .5,
    this.phaseRiskMultiplierMax = 1.5,
    this.pijolScarcityWeightMax = 20,
    this.figureOpportunityCostMin = 0,
    this.figureOpportunityCostMax = 40,
    this.schoolFaceOpportunityCostMax = 40,
    this.schoolOpeningFaceCostMin = -3,
    this.schoolOpeningFaceCostMax = 3,
    this.schoolBonusTargetWeightMax = 100,
    this.perfectColumnProgressWeightMax = 100,
    this.schoolPointWeightMax = 1,
    this.schoolNegativePenaltyWeightMax = 20,
    this.figureCompletionValueWeightMax = 40,
    this.rareFigureChaseWeightMax = 40,
    this.straightChaseWeightMax = 40,
    this.futureFieldValueWeightMax = 2,
    this.figureSpecificOpportunityCostMax = 40,
    this.figureSpecificOpportunityCostMin = 0,
  });

  static const standard = AdvisorWeightSearchSpace(
    openingColumnValueMax: 40,
    chanceCostEarlyMax: 45,
    chanceCostLateMax: 30,
    pijolBaseCostMax: 60,
    perfectColumnRiskCostMax: 160,
    schoolBonusProgressWeightMax: 5,
    schoolCompletionValueMax: 40,
    pijolGroupCostMax: 100,
  );

  static const wide = AdvisorWeightSearchSpace(
    openingColumnValueMax: 60,
    chanceCostEarlyMax: 90,
    chanceCostLateMax: 60,
    pijolBaseCostMax: 90,
    perfectColumnRiskCostMax: 320,
    schoolBonusProgressWeightMax: 10,
    schoolCompletionValueMax: 80,
    pijolGroupCostMax: 200,
    rerollValueWeightMin: -2,
    figureOpportunityCostMin: -20,
    figureSpecificOpportunityCostMin: -20,
  );

  List<String> boundaryHits(
    AdvisorWeightCandidate candidate, {
    double tolerance = .02,
  }) {
    final hits = <String>[];
    void addIfClose(String name, double value, double maximum) {
      if (maximum <= 0) return;
      if (value >= maximum * (1 - tolerance)) {
        hits.add(
          '$name=${value.toStringAsFixed(2)}/${maximum.toStringAsFixed(2)}',
        );
      }
    }

    addIfClose(
      'openingColumnValue',
      candidate.openingColumnValue,
      openingColumnValueMax,
    );
    addIfClose(
      'chanceCostEarly',
      candidate.chanceCostEarly,
      chanceCostEarlyMax,
    );
    addIfClose(
      'rerollValueWeight',
      candidate.rerollValueWeight,
      rerollValueWeightMax,
    );
    addIfClose(
      'rerollLowScoreWeight',
      candidate.rerollLowScoreWeight,
      rerollLowScoreWeightMax,
    );
    addIfClose('chanceCostLate', candidate.chanceCostLate, chanceCostLateMax);
    addIfClose('pijolBaseCost', candidate.pijolBaseCost, pijolBaseCostMax);
    addIfClose(
      'perfectColumnRiskCost',
      candidate.perfectColumnRiskCost,
      perfectColumnRiskCostMax,
    );
    addIfClose(
      'schoolBonusProgressWeight',
      candidate.schoolBonusProgressWeight,
      schoolBonusProgressWeightMax,
    );
    addIfClose(
      'schoolCompletionValue',
      candidate.schoolCompletionValue,
      schoolCompletionValueMax,
    );
    addIfClose(
      'pijolScarcityWeight',
      candidate.pijolScarcityWeight,
      pijolScarcityWeightMax,
    );
    for (final group in PijolFigureGroup.values) {
      addIfClose(
        'figureOpportunityCosts.${group.name}',
        candidate.figureOpportunityCosts[group] ?? 0,
        figureOpportunityCostMax,
      );
    }
    for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++) {
      addIfClose(
        'schoolFaceOpportunityCosts.$face',
        candidate.schoolFaceOpportunityCosts[face] ?? 0,
        schoolFaceOpportunityCostMax,
      );
      addIfClose(
        'schoolOpeningFaceCosts.$face',
        candidate.schoolOpeningFaceCosts[face] ?? 0,
        schoolOpeningFaceCostMax,
      );
    }
    addIfClose(
      'futureFieldValueWeight',
      candidate.futureFieldValueWeight,
      futureFieldValueWeightMax,
    );
    addIfClose(
      'schoolBonusTargetWeight',
      candidate.schoolBonusTargetWeight,
      schoolBonusTargetWeightMax,
    );
    addIfClose(
      'perfectColumnProgressWeight',
      candidate.perfectColumnProgressWeight,
      perfectColumnProgressWeightMax,
    );
    addIfClose(
      'schoolPointWeight',
      candidate.schoolPointWeight,
      schoolPointWeightMax,
    );
    addIfClose(
      'schoolNegativePenaltyWeight',
      candidate.schoolNegativePenaltyWeight,
      schoolNegativePenaltyWeightMax,
    );
    addIfClose(
      'figureCompletionValueWeight',
      candidate.figureCompletionValueWeight,
      figureCompletionValueWeightMax,
    );
    addIfClose(
      'rareFigureChaseWeight',
      candidate.rareFigureChaseWeight,
      rareFigureChaseWeightMax,
    );
    addIfClose(
      'straightChaseWeight',
      candidate.straightChaseWeight,
      straightChaseWeightMax,
    );
    for (final figure in Figure.values) {
      addIfClose(
        'figureSpecificOpportunityCosts.${figure.name}',
        candidate.figureSpecificOpportunityCosts[figure] ?? 0,
        figureSpecificOpportunityCostMax,
      );
    }
    for (final group in PijolFigureGroup.values) {
      addIfClose(
        'pijolGroupCosts.${group.name}',
        candidate.pijolGroupCosts[group] ?? 0,
        pijolGroupCostMax,
      );
    }
    return hits;
  }

  Map<String, double> toJson() => {
    'openingColumnValueMax': openingColumnValueMax,
    'chanceCostEarlyMax': chanceCostEarlyMax,
    'chanceCostLateMax': chanceCostLateMax,
    'rerollValueWeightMax': rerollValueWeightMax,
    'rerollValueWeightMin': rerollValueWeightMin,
    'rerollLowScoreWeightMax': rerollLowScoreWeightMax,
    'pijolBaseCostMax': pijolBaseCostMax,
    'perfectColumnRiskCostMax': perfectColumnRiskCostMax,
    'schoolBonusProgressWeightMax': schoolBonusProgressWeightMax,
    'schoolCompletionValueMax': schoolCompletionValueMax,
    'pijolGroupCostMax': pijolGroupCostMax,
    'phaseRiskMultiplierMin': phaseRiskMultiplierMin,
    'phaseRiskMultiplierMax': phaseRiskMultiplierMax,
    'pijolScarcityWeightMax': pijolScarcityWeightMax,
    'figureOpportunityCostMin': figureOpportunityCostMin,
    'figureOpportunityCostMax': figureOpportunityCostMax,
    'schoolFaceOpportunityCostMax': schoolFaceOpportunityCostMax,
    'schoolOpeningFaceCostMin': schoolOpeningFaceCostMin,
    'schoolOpeningFaceCostMax': schoolOpeningFaceCostMax,
    'schoolBonusTargetWeightMax': schoolBonusTargetWeightMax,
    'perfectColumnProgressWeightMax': perfectColumnProgressWeightMax,
    'schoolPointWeightMax': schoolPointWeightMax,
    'schoolNegativePenaltyWeightMax': schoolNegativePenaltyWeightMax,
    'figureCompletionValueWeightMax': figureCompletionValueWeightMax,
    'rareFigureChaseWeightMax': rareFigureChaseWeightMax,
    'straightChaseWeightMax': straightChaseWeightMax,
    'futureFieldValueWeightMax': futureFieldValueWeightMax,
    'figureSpecificOpportunityCostMax': figureSpecificOpportunityCostMax,
    'figureSpecificOpportunityCostMin': figureSpecificOpportunityCostMin,
  };
}

class AdvisorWeightCandidate {
  final double openingColumnValue;
  final double chanceCostEarly;
  final double chanceCostLate;
  final double rerollValueWeight;
  final double rerollLowScoreWeight;
  final double pijolBaseCost;
  final double perfectColumnRiskCost;
  final double schoolBonusProgressWeight;
  final double schoolCompletionValue;
  final double earlyGameRiskMultiplier;
  final double middleGameRiskMultiplier;
  final double lateGameRiskMultiplier;
  final double pijolScarcityWeight;
  final Map<PijolFigureGroup, double> figureOpportunityCosts;
  final Map<Figure, double> figureSpecificOpportunityCosts;
  final Map<int, double> schoolFaceOpportunityCosts;
  final Map<int, double> schoolOpeningFaceCosts;
  final double futureFieldValueWeight;
  final double schoolBonusTargetWeight;
  final double perfectColumnProgressWeight;
  final double schoolPointWeight;
  final double schoolNegativePenaltyWeight;
  final double figureCompletionValueWeight;
  final double rareFigureChaseWeight;
  final double straightChaseWeight;
  final Map<PijolFigureGroup, double> pijolGroupCosts;

  const AdvisorWeightCandidate({
    required this.openingColumnValue,
    required this.chanceCostEarly,
    required this.chanceCostLate,
    this.rerollValueWeight = 0,
    this.rerollLowScoreWeight = 0,
    required this.pijolBaseCost,
    required this.perfectColumnRiskCost,
    this.schoolBonusProgressWeight = 0,
    this.schoolCompletionValue = 0,
    this.earlyGameRiskMultiplier = 1,
    this.middleGameRiskMultiplier = 1,
    this.lateGameRiskMultiplier = 1,
    this.pijolScarcityWeight = 0,
    this.figureOpportunityCosts = const {},
    this.figureSpecificOpportunityCosts = const {},
    this.schoolFaceOpportunityCosts = const {},
    this.schoolOpeningFaceCosts = const {},
    this.futureFieldValueWeight = 0,
    this.schoolBonusTargetWeight = 0,
    this.perfectColumnProgressWeight = 0,
    this.schoolPointWeight = 0,
    this.schoolNegativePenaltyWeight = 0,
    this.figureCompletionValueWeight = 0,
    this.rareFigureChaseWeight = 0,
    this.straightChaseWeight = 0,
    this.pijolGroupCosts = const {},
  });

  AdvisorWeightCandidate copyWith({
    double? openingColumnValue,
    double? chanceCostEarly,
    double? chanceCostLate,
    double? rerollValueWeight,
    double? rerollLowScoreWeight,
    double? pijolBaseCost,
    double? perfectColumnRiskCost,
    double? schoolBonusProgressWeight,
    double? schoolCompletionValue,
    double? schoolNegativePenaltyWeight,
    double? figureCompletionValueWeight,
    double? rareFigureChaseWeight,
    double? straightChaseWeight,
    Map<int, double>? schoolOpeningFaceCosts,
  }) => AdvisorWeightCandidate(
    openingColumnValue: openingColumnValue ?? this.openingColumnValue,
    chanceCostEarly: chanceCostEarly ?? this.chanceCostEarly,
    chanceCostLate: chanceCostLate ?? this.chanceCostLate,
    rerollValueWeight: rerollValueWeight ?? this.rerollValueWeight,
    rerollLowScoreWeight: rerollLowScoreWeight ?? this.rerollLowScoreWeight,
    pijolBaseCost: pijolBaseCost ?? this.pijolBaseCost,
    perfectColumnRiskCost: perfectColumnRiskCost ?? this.perfectColumnRiskCost,
    schoolBonusProgressWeight:
        schoolBonusProgressWeight ?? this.schoolBonusProgressWeight,
    schoolCompletionValue: schoolCompletionValue ?? this.schoolCompletionValue,
    schoolNegativePenaltyWeight:
        schoolNegativePenaltyWeight ?? this.schoolNegativePenaltyWeight,
    figureCompletionValueWeight:
        figureCompletionValueWeight ?? this.figureCompletionValueWeight,
    rareFigureChaseWeight: rareFigureChaseWeight ?? this.rareFigureChaseWeight,
    straightChaseWeight: straightChaseWeight ?? this.straightChaseWeight,
    earlyGameRiskMultiplier: earlyGameRiskMultiplier,
    middleGameRiskMultiplier: middleGameRiskMultiplier,
    lateGameRiskMultiplier: lateGameRiskMultiplier,
    pijolScarcityWeight: pijolScarcityWeight,
    figureOpportunityCosts: figureOpportunityCosts,
    figureSpecificOpportunityCosts: figureSpecificOpportunityCosts,
    schoolFaceOpportunityCosts: schoolFaceOpportunityCosts,
    schoolOpeningFaceCosts:
        schoolOpeningFaceCosts ?? this.schoolOpeningFaceCosts,
    futureFieldValueWeight: futureFieldValueWeight,
    schoolBonusTargetWeight: schoolBonusTargetWeight,
    perfectColumnProgressWeight: perfectColumnProgressWeight,
    schoolPointWeight: schoolPointWeight,
    pijolGroupCosts: pijolGroupCosts,
  );

  factory AdvisorWeightCandidate.defaults() {
    const weights = AdvisorWeights();
    final groupedOpportunityCosts = {
      for (final group in PijolFigureGroup.values)
        group:
            weights.fieldOpportunityCosts[Figure.values.firstWhere(
              (figure) => pijolGroupFor(figure) == group,
            )] ??
            0,
    };
    return AdvisorWeightCandidate(
      openingColumnValue: weights.openingColumnValue,
      chanceCostEarly: weights.chanceCostEarly,
      chanceCostLate: weights.chanceCostLate,
      rerollValueWeight: weights.rerollValueWeight,
      rerollLowScoreWeight: weights.rerollLowScoreWeight,
      pijolBaseCost: weights.pijolBaseCost,
      perfectColumnRiskCost: weights.perfectColumnRiskCost,
      schoolBonusProgressWeight: weights.schoolBonusProgressWeight,
      schoolCompletionValue: weights.schoolCompletionValue,
      schoolNegativePenaltyWeight: weights.schoolNegativePenaltyWeight,
      figureCompletionValueWeight: weights.figureCompletionValueWeight,
      rareFigureChaseWeight: weights.rareFigureChaseWeight,
      straightChaseWeight: weights.straightChaseWeight,
      earlyGameRiskMultiplier: weights.earlyGameRiskMultiplier,
      middleGameRiskMultiplier: weights.middleGameRiskMultiplier,
      lateGameRiskMultiplier: weights.lateGameRiskMultiplier,
      pijolScarcityWeight: weights.pijolScarcityWeight,
      figureOpportunityCosts: groupedOpportunityCosts,
      schoolFaceOpportunityCosts: weights.schoolFaceOpportunityCosts,
      schoolOpeningFaceCosts: weights.schoolOpeningFaceCosts,
      futureFieldValueWeight: weights.futureFieldValueWeight,
      schoolBonusTargetWeight: weights.schoolBonusTargetWeight,
      perfectColumnProgressWeight: weights.perfectColumnProgressWeight,
      schoolPointWeight: weights.schoolPointWeight,
      figureSpecificOpportunityCosts: {
        for (final figure in Figure.values)
          if (weights.fieldOpportunityCosts[figure] !=
              groupedOpportunityCosts[pijolGroupFor(figure)])
            figure: weights.fieldOpportunityCosts[figure] ?? 0,
      },
      pijolGroupCosts: {
        for (final group in PijolFigureGroup.values)
          group:
              weights.pijolFieldCosts[Figure.values.firstWhere(
                (figure) => pijolGroupFor(figure) == group,
              )] ??
              0,
      },
    );
  }

  factory AdvisorWeightCandidate.zero() => const AdvisorWeightCandidate(
    openingColumnValue: 0,
    chanceCostEarly: 0,
    chanceCostLate: 0,
    pijolBaseCost: 0,
    perfectColumnRiskCost: 0,
  );

  factory AdvisorWeightCandidate.fromJson(Map<String, dynamic> json) {
    final nestedWeights = json['weights'];
    final source = nestedWeights is Map
        ? Map<String, dynamic>.from(nestedWeights)
        : json;
    final groupJson = source['pijolGroupCosts'];
    final groups = groupJson is Map
        ? Map<String, dynamic>.from(groupJson)
        : const <String, dynamic>{};
    final opportunityJson = source['figureOpportunityCosts'];
    final opportunityGroups = opportunityJson is Map
        ? Map<String, dynamic>.from(opportunityJson)
        : const <String, dynamic>{};
    final specificJson = source['figureSpecificOpportunityCosts'];
    final specificCosts = specificJson is Map
        ? Map<String, dynamic>.from(specificJson)
        : const <String, dynamic>{};
    final schoolJson = source['schoolFaceOpportunityCosts'];
    final schoolCosts = schoolJson is Map
        ? Map<String, dynamic>.from(schoolJson)
        : const <String, dynamic>{};
    final schoolOpeningJson = source['schoolOpeningFaceCosts'];
    final schoolOpeningCosts = schoolOpeningJson is Map
        ? Map<String, dynamic>.from(schoolOpeningJson)
        : const <String, dynamic>{};
    const defaults = AdvisorWeights();
    return AdvisorWeightCandidate(
      openingColumnValue: _jsonDouble(
        source,
        'openingColumnValue',
        defaults.openingColumnValue,
      ),
      chanceCostEarly: _jsonDouble(
        source,
        'chanceCostEarly',
        defaults.chanceCostEarly,
      ),
      chanceCostLate: _jsonDouble(
        source,
        'chanceCostLate',
        defaults.chanceCostLate,
      ),
      rerollValueWeight: _jsonDouble(
        source,
        'rerollValueWeight',
        defaults.rerollValueWeight,
      ),
      rerollLowScoreWeight: _jsonDouble(
        source,
        'rerollLowScoreWeight',
        defaults.rerollLowScoreWeight,
      ),
      pijolBaseCost: _jsonDouble(
        source,
        'pijolBaseCost',
        defaults.pijolBaseCost,
      ),
      perfectColumnRiskCost: _jsonDouble(
        source,
        'perfectColumnRiskCost',
        defaults.perfectColumnRiskCost,
      ),
      schoolBonusProgressWeight: _jsonDouble(
        source,
        'schoolBonusProgressWeight',
        defaults.schoolBonusProgressWeight,
      ),
      schoolCompletionValue: _jsonDouble(
        source,
        'schoolCompletionValue',
        defaults.schoolCompletionValue,
      ),
      earlyGameRiskMultiplier: _jsonDouble(
        source,
        'earlyGameRiskMultiplier',
        defaults.earlyGameRiskMultiplier,
      ),
      middleGameRiskMultiplier: _jsonDouble(
        source,
        'middleGameRiskMultiplier',
        defaults.middleGameRiskMultiplier,
      ),
      lateGameRiskMultiplier: _jsonDouble(
        source,
        'lateGameRiskMultiplier',
        defaults.lateGameRiskMultiplier,
      ),
      pijolScarcityWeight: _jsonDouble(
        source,
        'pijolScarcityWeight',
        defaults.pijolScarcityWeight,
      ),
      figureOpportunityCosts: {
        for (final group in PijolFigureGroup.values)
          group: _jsonDouble(opportunityGroups, group.name, 0),
      },
      schoolFaceOpportunityCosts: {
        for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++)
          face: _jsonDouble(schoolCosts, '$face', 0),
      },
      schoolOpeningFaceCosts: {
        for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++)
          face: _jsonDouble(
            schoolOpeningCosts,
            '$face',
            defaults.schoolOpeningFaceCosts[face] ?? 0,
          ),
      },
      futureFieldValueWeight: _jsonDouble(
        source,
        'futureFieldValueWeight',
        defaults.futureFieldValueWeight,
      ),
      schoolBonusTargetWeight: _jsonDouble(
        source,
        'schoolBonusTargetWeight',
        defaults.schoolBonusTargetWeight,
      ),
      perfectColumnProgressWeight: _jsonDouble(
        source,
        'perfectColumnProgressWeight',
        defaults.perfectColumnProgressWeight,
      ),
      schoolPointWeight: _jsonDouble(
        source,
        'schoolPointWeight',
        defaults.schoolPointWeight,
      ),
      schoolNegativePenaltyWeight: _jsonDouble(
        source,
        'schoolNegativePenaltyWeight',
        defaults.schoolNegativePenaltyWeight,
      ),
      figureCompletionValueWeight: _jsonDouble(
        source,
        'figureCompletionValueWeight',
        defaults.figureCompletionValueWeight,
      ),
      rareFigureChaseWeight: _jsonDouble(
        source,
        'rareFigureChaseWeight',
        defaults.rareFigureChaseWeight,
      ),
      straightChaseWeight: _jsonDouble(
        source,
        'straightChaseWeight',
        defaults.straightChaseWeight,
      ),
      figureSpecificOpportunityCosts: {
        for (final entry in specificCosts.entries)
          if (Figure.values.any((figure) => figure.name == entry.key))
            Figure.values.firstWhere((figure) => figure.name == entry.key):
                _jsonDouble(specificCosts, entry.key, 0),
      },
      pijolGroupCosts: {
        for (final group in PijolFigureGroup.values)
          group: _jsonDouble(groups, group.name, 0),
      },
    );
  }

  AdvisorWeights get weights => AdvisorWeights(
    openingColumnValue: openingColumnValue,
    chanceCostEarly: chanceCostEarly,
    chanceCostLate: chanceCostLate,
    rerollValueWeight: rerollValueWeight,
    rerollLowScoreWeight: rerollLowScoreWeight,
    pijolBaseCost: pijolBaseCost,
    perfectColumnRiskCost: perfectColumnRiskCost,
    schoolBonusProgressWeight: schoolBonusProgressWeight,
    schoolCompletionValue: schoolCompletionValue,
    earlyGameRiskMultiplier: earlyGameRiskMultiplier,
    middleGameRiskMultiplier: middleGameRiskMultiplier,
    lateGameRiskMultiplier: lateGameRiskMultiplier,
    pijolScarcityWeight: pijolScarcityWeight,
    fieldOpportunityCosts: {
      for (final figure in Figure.values)
        figure:
            figureSpecificOpportunityCosts[figure] ??
            figureOpportunityCosts[pijolGroupFor(figure)] ??
            0,
    },
    schoolFaceOpportunityCosts: schoolFaceOpportunityCosts,
    schoolOpeningFaceCosts: schoolOpeningFaceCosts,
    futureFieldValueWeight: futureFieldValueWeight,
    schoolBonusTargetWeight: schoolBonusTargetWeight,
    perfectColumnProgressWeight: perfectColumnProgressWeight,
    schoolPointWeight: schoolPointWeight,
    schoolNegativePenaltyWeight: schoolNegativePenaltyWeight,
    figureCompletionValueWeight: figureCompletionValueWeight,
    rareFigureChaseWeight: rareFigureChaseWeight,
    straightChaseWeight: straightChaseWeight,
    pijolFieldCosts: {
      for (final figure in Figure.values)
        figure: pijolGroupCosts[pijolGroupFor(figure)] ?? 0,
    },
  );

  String get cacheKey => [
    openingColumnValue,
    chanceCostEarly,
    chanceCostLate,
    rerollValueWeight,
    rerollLowScoreWeight,
    pijolBaseCost,
    perfectColumnRiskCost,
    schoolBonusProgressWeight,
    schoolCompletionValue,
    earlyGameRiskMultiplier,
    middleGameRiskMultiplier,
    lateGameRiskMultiplier,
    pijolScarcityWeight,
    for (final group in PijolFigureGroup.values)
      figureOpportunityCosts[group] ?? 0,
    for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++)
      schoolFaceOpportunityCosts[face] ?? 0,
    for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++)
      schoolOpeningFaceCosts[face] ?? 0,
    futureFieldValueWeight,
    schoolBonusTargetWeight,
    perfectColumnProgressWeight,
    schoolPointWeight,
    schoolNegativePenaltyWeight,
    figureCompletionValueWeight,
    rareFigureChaseWeight,
    straightChaseWeight,
    for (final figure in Figure.values)
      figureSpecificOpportunityCosts[figure] ?? 0,
    for (final group in PijolFigureGroup.values) pijolGroupCosts[group] ?? 0,
  ].map((value) => value.toStringAsFixed(8)).join('|');

  Map<String, Object> toJson() => {
    'openingColumnValue': openingColumnValue,
    'chanceCostEarly': chanceCostEarly,
    'chanceCostLate': chanceCostLate,
    'rerollValueWeight': rerollValueWeight,
    'rerollLowScoreWeight': rerollLowScoreWeight,
    'pijolBaseCost': pijolBaseCost,
    'perfectColumnRiskCost': perfectColumnRiskCost,
    'schoolBonusProgressWeight': schoolBonusProgressWeight,
    'schoolCompletionValue': schoolCompletionValue,
    'earlyGameRiskMultiplier': earlyGameRiskMultiplier,
    'middleGameRiskMultiplier': middleGameRiskMultiplier,
    'lateGameRiskMultiplier': lateGameRiskMultiplier,
    'pijolScarcityWeight': pijolScarcityWeight,
    'figureOpportunityCosts': {
      for (final group in PijolFigureGroup.values)
        group.name: figureOpportunityCosts[group] ?? 0,
    },
    'schoolFaceOpportunityCosts': {
      for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++)
        '$face': schoolFaceOpportunityCosts[face] ?? 0,
    },
    'schoolOpeningFaceCosts': {
      for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++)
        '$face': schoolOpeningFaceCosts[face] ?? 0,
    },
    'futureFieldValueWeight': futureFieldValueWeight,
    'schoolBonusTargetWeight': schoolBonusTargetWeight,
    'perfectColumnProgressWeight': perfectColumnProgressWeight,
    'schoolPointWeight': schoolPointWeight,
    'schoolNegativePenaltyWeight': schoolNegativePenaltyWeight,
    'figureCompletionValueWeight': figureCompletionValueWeight,
    'rareFigureChaseWeight': rareFigureChaseWeight,
    'straightChaseWeight': straightChaseWeight,
    'figureSpecificOpportunityCosts': {
      for (final entry in figureSpecificOpportunityCosts.entries)
        if (entry.value != 0) entry.key.name: entry.value,
    },
    'pijolGroupCosts': {
      for (final group in PijolFigureGroup.values)
        group.name: pijolGroupCosts[group] ?? 0,
    },
  };
}

class WeightOptimizerOptions {
  final int populationSize;
  final int generations;
  final int minimumTrainingGames;
  final int trainingGames;
  final int validationCandidateCount;
  final int validationGames;
  final int testGames;
  final int firstTrainingSeed;
  final int firstValidationSeed;
  final int firstTestSeed;
  final int workers;
  final int optimizerSeed;
  final AdvisorWeightSearchSpace searchSpace;

  const WeightOptimizerOptions({
    this.populationSize = 6,
    this.generations = 2,
    this.minimumTrainingGames = 1,
    this.trainingGames = 1,
    this.validationCandidateCount = 2,
    this.validationGames = 1,
    this.testGames = 1,
    this.firstTrainingSeed = 1,
    this.firstValidationSeed = 1000001,
    this.firstTestSeed = 2000001,
    this.workers = 1,
    this.optimizerSeed = 20260903,
    this.searchSpace = AdvisorWeightSearchSpace.standard,
  });

  void validate() {
    if (populationSize < 2) {
      throw ArgumentError.value(
        populationSize,
        'populationSize',
        'Must be at least 2.',
      );
    }
    if (generations <= 0 ||
        minimumTrainingGames <= 0 ||
        trainingGames < minimumTrainingGames ||
        validationGames <= 0 ||
        testGames <= 0) {
      throw ArgumentError(
        'Generation and game counts must be positive, and maximum training '
        'games cannot be lower than the minimum.',
      );
    }
    if (validationCandidateCount <= 0 ||
        validationCandidateCount > populationSize) {
      throw ArgumentError.value(
        validationCandidateCount,
        'validationCandidateCount',
        'Must be between 1 and the population size.',
      );
    }
    if (workers <= 0) {
      throw ArgumentError.value(workers, 'workers', 'Must be positive.');
    }
  }

  Map<String, Object> toJson() => {
    'populationSize': populationSize,
    'generations': generations,
    'minimumTrainingGames': minimumTrainingGames,
    'trainingGames': trainingGames,
    'validationCandidateCount': validationCandidateCount,
    'validationGames': validationGames,
    'testGames': testGames,
    'firstTrainingSeed': firstTrainingSeed,
    'firstValidationSeed': firstValidationSeed,
    'firstTestSeed': firstTestSeed,
    'workers': workers,
    'optimizerSeed': optimizerSeed,
    'searchSpace': searchSpace.toJson(),
  };
}

class WeightOptimizationProgress {
  final int generation;
  final int candidateIndex;
  final int populationSize;
  final int trainingGames;
  final AdvisorWeightCandidate candidate;
  final double meanScore;
  final bool cached;

  const WeightOptimizationProgress({
    required this.generation,
    required this.candidateIndex,
    required this.populationSize,
    required this.trainingGames,
    required this.candidate,
    required this.meanScore,
    required this.cached,
  });
}

class ValidatedWeightCandidate {
  final AdvisorWeightCandidate candidate;
  final SimulationReport trainingReport;
  final SimulationReport validationReport;
  final StrategyComparison validationComparison;

  const ValidatedWeightCandidate({
    required this.candidate,
    required this.trainingReport,
    required this.validationReport,
    required this.validationComparison,
  });

  Map<String, Object> toJson() => {
    'weights': candidate.toJson(),
    'trainingScore': trainingReport.totalScore.mean,
    'validationScore': validationReport.totalScore.mean,
    'comparison': validationComparison.toJson(),
  };
}

class WeightOptimizationResult {
  final String profileName;
  final WeightOptimizerOptions options;
  final AdvisorWeightCandidate bestCandidate;
  final SimulationReport trainingReport;
  final SimulationReport validationReport;
  final SimulationReport validationBaselineReport;
  final SimulationReport testReport;
  final SimulationReport testBaselineReport;
  final List<ValidatedWeightCandidate> validatedCandidates;
  final List<double> bestScoreByGeneration;

  const WeightOptimizationResult({
    required this.profileName,
    required this.options,
    required this.bestCandidate,
    required this.trainingReport,
    required this.validationReport,
    required this.validationBaselineReport,
    required this.testReport,
    required this.testBaselineReport,
    required this.validatedCandidates,
    required this.bestScoreByGeneration,
  });

  StrategyComparison get validationComparison => StrategyComparison(
    candidate: validationReport,
    baseline: validationBaselineReport,
  );

  StrategyComparison get testComparison =>
      StrategyComparison(candidate: testReport, baseline: testBaselineReport);

  WeightOptimizationResult copyWithBestCandidate(
    AdvisorWeightCandidate candidate,
  ) => WeightOptimizationResult(
    profileName: profileName,
    options: options,
    bestCandidate: candidate,
    trainingReport: trainingReport,
    validationReport: validationReport,
    validationBaselineReport: validationBaselineReport,
    testReport: testReport,
    testBaselineReport: testBaselineReport,
    validatedCandidates: validatedCandidates,
    bestScoreByGeneration: bestScoreByGeneration,
  );

  WeightOptimizationResult copyWithExactReports({
    required AdvisorWeightCandidate candidate,
    required SimulationReport training,
    required SimulationReport validation,
    required SimulationReport test,
  }) => WeightOptimizationResult(
    profileName: profileName,
    options: options,
    bestCandidate: candidate,
    trainingReport: training,
    validationReport: validation,
    validationBaselineReport: validationBaselineReport,
    testReport: test,
    testBaselineReport: testBaselineReport,
    validatedCandidates: validatedCandidates,
    bestScoreByGeneration: bestScoreByGeneration,
  );

  bool get isValidatedImprovement =>
      testReport.gameCount >= 30 &&
      testComparison.scoreDifference.mean -
              testComparison.confidence95HalfWidth >
          0;

  Map<String, Object> toJson() => {
    'profileVersion': 2,
    'profileName': profileName,
    'experiment': options.toJson(),
    'weights': bestCandidate.toJson(),
    'training': trainingReport.toJson(),
    'validation': validationReport.toJson(),
    'validationBaseline': validationBaselineReport.toJson(),
    'validationComparison': validationComparison.toJson(),
    'test': testReport.toJson(),
    'testBaseline': testBaselineReport.toJson(),
    'testComparison': testComparison.toJson(),
    'isValidatedImprovement': isValidatedImprovement,
    'validatedCandidates': validatedCandidates
        .map((candidate) => candidate.toJson())
        .toList(),
    'bestScoreByGeneration': bestScoreByGeneration,
  };
}

typedef OptimizationProgressCallback = void Function(
  WeightOptimizationProgress progress,
);

class AdvisorWeightOptimizer {
  final SimulationRunner runner;

  const AdvisorWeightOptimizer({this.runner = const SimulationRunner()});

  Future<WeightOptimizationResult> optimize({
    WeightOptimizerOptions options = const WeightOptimizerOptions(),
    String profileName = 'optimized-v2',
    bool fastTraining = false,
    List<AdvisorWeightCandidate> initialCandidates = const [],
    OptimizationProgressCallback? onProgress,
  }) async {
    options.validate();
    final random = Random(options.optimizerSeed);
    var population = _initialPopulation(
      options.populationSize,
      random,
      options.searchSpace,
      initialCandidates,
    );
    final reportCache = <String, SimulationReport>{};
    final bestScoreByGeneration = <double>[];
    var finalRanking = <_EvaluatedCandidate>[];

    for (var generation = 0; generation < options.generations; generation++) {
      final gameCount = _trainingGamesForGeneration(options, generation);
      final evaluated = <_EvaluatedCandidate>[];
      for (var index = 0; index < population.length; index++) {
        final candidate = population[index];
        final cacheKey = candidate.cacheKey;
        final cachedReport = reportCache[cacheKey];
        late final SimulationReport report;
        if (cachedReport == null) {
          report = await runner.runParallel(
            strategy: _strategyFor(
              fastTraining: fastTraining,
              name: 'candidate-g${generation + 1}-${index + 1}',
              weights: candidate.weights,
            ),
            gameCount: gameCount,
            firstSeed: options.firstTrainingSeed,
            workers: options.workers,
          );
        } else if (cachedReport.gameCount == gameCount) {
          report = cachedReport;
        } else {
          final additional = await runner.runParallel(
            strategy: _strategyFor(
              fastTraining: fastTraining,
              name: 'candidate-g${generation + 1}-${index + 1}',
              weights: candidate.weights,
            ),
            gameCount: gameCount - cachedReport.gameCount,
            firstSeed: options.firstTrainingSeed + cachedReport.gameCount,
            workers: options.workers,
          );
          report = SimulationReport(
            strategyName: additional.strategyName,
            games: List.unmodifiable([
              ...cachedReport.games,
              ...additional.games,
            ]),
            elapsed: cachedReport.elapsed + additional.elapsed,
          );
        }
        reportCache[cacheKey] = report;
        evaluated.add(_EvaluatedCandidate(candidate, report));
        onProgress?.call(
          WeightOptimizationProgress(
            generation: generation + 1,
            candidateIndex: index + 1,
            populationSize: population.length,
            trainingGames: gameCount,
            candidate: candidate,
            meanScore: report.totalScore.mean,
            cached: cachedReport != null,
          ),
        );
      }
      evaluated.sort(_compareEvaluatedCandidates);
      finalRanking = evaluated;
      bestScoreByGeneration.add(evaluated.first.report.totalScore.mean);
      if (generation + 1 < options.generations) {
        population = _nextGeneration(
          evaluated,
          options.populationSize,
          generation,
          options.generations,
          random,
          options.searchSpace,
        );
      }
    }

    final validationBaselineReport = await runner.runParallel(
      strategy: const AdvisorGameStrategy(name: 'default-validation-baseline'),
      gameCount: options.validationGames,
      firstSeed: options.firstValidationSeed,
      workers: options.workers,
    );
    final finalists = _uniqueFinalists(
      finalRanking,
      options.validationCandidateCount,
    );
    final baselineCandidate = AdvisorWeightCandidate.defaults();
    final baselineTraining = reportCache[baselineCandidate.cacheKey];
    if (baselineTraining != null &&
        !finalists.any(
          (finalist) =>
              finalist.candidate.cacheKey == baselineCandidate.cacheKey,
        )) {
      if (finalists.length >= options.validationCandidateCount) {
        finalists.removeLast();
      }
      finalists.add(_EvaluatedCandidate(baselineCandidate, baselineTraining));
    }
    final validated = <ValidatedWeightCandidate>[];
    for (var index = 0; index < finalists.length; index++) {
      final finalist = finalists[index];
      final report = await runner.runParallel(
        strategy: AdvisorGameStrategy.withWeights(
          name: 'validation-finalist-${index + 1}',
          weights: finalist.candidate.weights,
        ),
        gameCount: options.validationGames,
        firstSeed: options.firstValidationSeed,
        workers: options.workers,
      );
      validated.add(
        ValidatedWeightCandidate(
          candidate: finalist.candidate,
          trainingReport: finalist.report,
          validationReport: report,
          validationComparison: StrategyComparison(
            candidate: report,
            baseline: validationBaselineReport,
          ),
        ),
      );
    }
    validated.sort((left, right) {
      final validation = right.validationComparison.scoreDifference.mean
          .compareTo(left.validationComparison.scoreDifference.mean);
      if (validation != 0) return validation;
      return right.trainingReport.totalScore.mean.compareTo(
        left.trainingReport.totalScore.mean,
      );
    });
    final selected = validated.first;

    final testReport = await runner.runParallel(
      strategy: AdvisorGameStrategy.withWeights(
        name: '$profileName-test',
        weights: selected.candidate.weights,
      ),
      gameCount: options.testGames,
      firstSeed: options.firstTestSeed,
      workers: options.workers,
    );
    final testBaselineReport = await runner.runParallel(
      strategy: const AdvisorGameStrategy(name: 'default-test-baseline'),
      gameCount: options.testGames,
      firstSeed: options.firstTestSeed,
      workers: options.workers,
    );
    return WeightOptimizationResult(
      profileName: profileName,
      options: options,
      bestCandidate: selected.candidate,
      trainingReport: selected.trainingReport,
      validationReport: selected.validationReport,
      validationBaselineReport: validationBaselineReport,
      testReport: testReport,
      testBaselineReport: testBaselineReport,
      validatedCandidates: List.unmodifiable(validated),
      bestScoreByGeneration: List.unmodifiable(bestScoreByGeneration),
    );
  }

  GameStrategy _strategyFor({
    required bool fastTraining,
    required String name,
    required AdvisorWeights weights,
  }) => fastTraining
      ? FastAdvisorGameStrategy.withWeights(name: name, weights: weights)
      : AdvisorGameStrategy.withWeights(name: name, weights: weights);
}

class _EvaluatedCandidate {
  final AdvisorWeightCandidate candidate;
  final SimulationReport report;

  const _EvaluatedCandidate(this.candidate, this.report);
}

List<AdvisorWeightCandidate> _initialPopulation(
  int size,
  Random random,
  AdvisorWeightSearchSpace searchSpace,
  List<AdvisorWeightCandidate> initialCandidates,
) {
  final population = <AdvisorWeightCandidate>[];
  final seen = <String>{};
  void add(AdvisorWeightCandidate candidate) {
    if (population.length < size && seen.add(candidate.cacheKey)) {
      population.add(candidate);
    }
  }

  for (final candidate in initialCandidates) {
    add(candidate);
  }
  add(AdvisorWeightCandidate.defaults());
  add(AdvisorWeightCandidate.zero());
  while (population.length < size) {
    add(_randomCandidate(random, searchSpace));
  }
  return population;
}

int _trainingGamesForGeneration(
  WeightOptimizerOptions options,
  int generation,
) {
  if (options.generations == 1 ||
      options.minimumTrainingGames == options.trainingGames) {
    return options.trainingGames;
  }
  final progress = generation / (options.generations - 1);
  final ratio = options.trainingGames / options.minimumTrainingGames;
  return (options.minimumTrainingGames * pow(ratio, progress)).round();
}

List<_EvaluatedCandidate> _uniqueFinalists(
  List<_EvaluatedCandidate> ranking,
  int count,
) {
  final seen = <String>{};
  final result = <_EvaluatedCandidate>[];
  for (final candidate in ranking) {
    if (seen.add(candidate.candidate.cacheKey)) result.add(candidate);
    if (result.length == count) break;
  }
  if (result.isEmpty) throw StateError('No unique finalist was produced.');
  return result;
}

int _compareEvaluatedCandidates(
  _EvaluatedCandidate left,
  _EvaluatedCandidate right,
) => right.report.totalScore.mean.compareTo(left.report.totalScore.mean);

List<AdvisorWeightCandidate> _nextGeneration(
  List<_EvaluatedCandidate> evaluated,
  int populationSize,
  int generation,
  int generationCount,
  Random random,
  AdvisorWeightSearchSpace searchSpace,
) {
  final eliteCount = max(2, populationSize ~/ 4);
  final elites = evaluated.take(eliteCount).toList();
  final progress = generationCount == 1
      ? 1.0
      : generation / (generationCount - 1);
  final mutationScale = .20 * (1 - progress) + .04;
  return [
    for (final elite in elites) elite.candidate,
    for (var index = eliteCount; index < populationSize; index++)
      index.isEven
          ? _coordinateMutate(
              elites[random.nextInt(elites.length)].candidate,
              random,
              mutationScale,
              searchSpace,
            )
          : _mutate(
              elites[random.nextInt(elites.length)].candidate,
              random,
              mutationScale,
              searchSpace,
            ),
  ];
}

AdvisorWeightCandidate _randomCandidate(
  Random random,
  AdvisorWeightSearchSpace searchSpace,
) => AdvisorWeightCandidate(
  openingColumnValue: random.nextDouble() * searchSpace.openingColumnValueMax,
  chanceCostEarly: random.nextDouble() * searchSpace.chanceCostEarlyMax,
  chanceCostLate: random.nextDouble() * searchSpace.chanceCostLateMax,
  rerollValueWeight: _randomInRange(
    random,
    searchSpace.rerollValueWeightMin,
    searchSpace.rerollValueWeightMax,
  ),
  rerollLowScoreWeight:
      random.nextDouble() * searchSpace.rerollLowScoreWeightMax,
  pijolBaseCost: random.nextDouble() * searchSpace.pijolBaseCostMax,
  perfectColumnRiskCost:
      random.nextDouble() * searchSpace.perfectColumnRiskCostMax,
  schoolBonusProgressWeight:
      random.nextDouble() * searchSpace.schoolBonusProgressWeightMax,
  schoolCompletionValue:
      random.nextDouble() * searchSpace.schoolCompletionValueMax,
  earlyGameRiskMultiplier: _randomInRange(
    random,
    searchSpace.phaseRiskMultiplierMin,
    searchSpace.phaseRiskMultiplierMax,
  ),
  middleGameRiskMultiplier: _randomInRange(
    random,
    searchSpace.phaseRiskMultiplierMin,
    searchSpace.phaseRiskMultiplierMax,
  ),
  lateGameRiskMultiplier: _randomInRange(
    random,
    searchSpace.phaseRiskMultiplierMin,
    searchSpace.phaseRiskMultiplierMax,
  ),
  pijolScarcityWeight: random.nextDouble() * searchSpace.pijolScarcityWeightMax,
  figureOpportunityCosts: {
    for (final group in PijolFigureGroup.values)
      group: _randomInRange(
        random,
        searchSpace.figureOpportunityCostMin,
        searchSpace.figureOpportunityCostMax,
      ),
  },
  schoolFaceOpportunityCosts: {
    for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++)
      face: random.nextDouble() * searchSpace.schoolFaceOpportunityCostMax,
  },
  schoolOpeningFaceCosts: {
    for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++)
      face: _randomInRange(
        random,
        searchSpace.schoolOpeningFaceCostMin,
        searchSpace.schoolOpeningFaceCostMax,
      ),
  },
  futureFieldValueWeight:
      random.nextDouble() * searchSpace.futureFieldValueWeightMax,
  schoolBonusTargetWeight:
      random.nextDouble() * searchSpace.schoolBonusTargetWeightMax,
  perfectColumnProgressWeight:
      random.nextDouble() * searchSpace.perfectColumnProgressWeightMax,
  schoolPointWeight: random.nextDouble() * searchSpace.schoolPointWeightMax,
  schoolNegativePenaltyWeight:
      random.nextDouble() * searchSpace.schoolNegativePenaltyWeightMax,
  figureCompletionValueWeight:
      random.nextDouble() * searchSpace.figureCompletionValueWeightMax,
  rareFigureChaseWeight:
      random.nextDouble() * searchSpace.rareFigureChaseWeightMax,
  straightChaseWeight: random.nextDouble() * searchSpace.straightChaseWeightMax,
  figureSpecificOpportunityCosts: const {},
  pijolGroupCosts: {
    for (final group in PijolFigureGroup.values)
      group: random.nextDouble() * searchSpace.pijolGroupCostMax,
  },
);

AdvisorWeightCandidate _coordinateMutate(
  AdvisorWeightCandidate parent,
  Random random,
  double scale,
  AdvisorWeightSearchSpace searchSpace,
) {
  double mutate(double value, double maximum) =>
      _mutated(value, maximum, random, scale);
  return switch (random.nextInt(13)) {
    0 => parent.copyWith(
      openingColumnValue: mutate(
        parent.openingColumnValue,
        searchSpace.openingColumnValueMax,
      ),
    ),
    1 => parent.copyWith(
      chanceCostEarly: mutate(
        parent.chanceCostEarly,
        searchSpace.chanceCostEarlyMax,
      ),
    ),
    2 => parent.copyWith(
      chanceCostLate: mutate(
        parent.chanceCostLate,
        searchSpace.chanceCostLateMax,
      ),
    ),
    3 => parent.copyWith(
      rerollValueWeight: mutate(
        parent.rerollValueWeight,
        searchSpace.rerollValueWeightMax,
      ),
    ),
    4 => parent.copyWith(
      rerollLowScoreWeight: mutate(
        parent.rerollLowScoreWeight,
        searchSpace.rerollLowScoreWeightMax,
      ),
    ),
    5 => parent.copyWith(
      pijolBaseCost: mutate(parent.pijolBaseCost, searchSpace.pijolBaseCostMax),
    ),
    6 => parent.copyWith(
      perfectColumnRiskCost: mutate(
        parent.perfectColumnRiskCost,
        searchSpace.perfectColumnRiskCostMax,
      ),
    ),
    7 => parent.copyWith(
      schoolBonusProgressWeight: mutate(
        parent.schoolBonusProgressWeight,
        searchSpace.schoolBonusProgressWeightMax,
      ),
    ),
    8 => parent.copyWith(
      schoolNegativePenaltyWeight: mutate(
        parent.schoolNegativePenaltyWeight,
        searchSpace.schoolNegativePenaltyWeightMax,
      ),
    ),
    9 => parent.copyWith(
      figureCompletionValueWeight: mutate(
        parent.figureCompletionValueWeight,
        searchSpace.figureCompletionValueWeightMax,
      ),
    ),
    10 => parent.copyWith(
      rareFigureChaseWeight: mutate(
        parent.rareFigureChaseWeight,
        searchSpace.rareFigureChaseWeightMax,
      ),
    ),
    11 => parent.copyWith(
      straightChaseWeight: mutate(
        parent.straightChaseWeight,
        searchSpace.straightChaseWeightMax,
      ),
    ),
    _ => parent.copyWith(
      schoolCompletionValue: mutate(
        parent.schoolCompletionValue,
        searchSpace.schoolCompletionValueMax,
      ),
    ),
  };
}

AdvisorWeightCandidate _mutate(
  AdvisorWeightCandidate parent,
  Random random,
  double scale,
  AdvisorWeightSearchSpace searchSpace,
) => AdvisorWeightCandidate(
  openingColumnValue: _mutated(
    parent.openingColumnValue,
    searchSpace.openingColumnValueMax,
    random,
    scale,
  ),
  chanceCostEarly: _mutated(
    parent.chanceCostEarly,
    searchSpace.chanceCostEarlyMax,
    random,
    scale,
  ),
  chanceCostLate: _mutated(
    parent.chanceCostLate,
    searchSpace.chanceCostLateMax,
    random,
    scale,
  ),
  rerollValueWeight: _mutatedRange(
    parent.rerollValueWeight,
    searchSpace.rerollValueWeightMin,
    searchSpace.rerollValueWeightMax,
    random,
    scale,
  ),
  rerollLowScoreWeight: _mutated(
    parent.rerollLowScoreWeight,
    searchSpace.rerollLowScoreWeightMax,
    random,
    scale,
  ),
  pijolBaseCost: _mutated(
    parent.pijolBaseCost,
    searchSpace.pijolBaseCostMax,
    random,
    scale,
  ),
  perfectColumnRiskCost: _mutated(
    parent.perfectColumnRiskCost,
    searchSpace.perfectColumnRiskCostMax,
    random,
    scale,
  ),
  schoolBonusProgressWeight: _mutated(
    parent.schoolBonusProgressWeight,
    searchSpace.schoolBonusProgressWeightMax,
    random,
    scale,
  ),
  schoolCompletionValue: _mutated(
    parent.schoolCompletionValue,
    searchSpace.schoolCompletionValueMax,
    random,
    scale,
  ),
  earlyGameRiskMultiplier: _mutatedRange(
    parent.earlyGameRiskMultiplier,
    searchSpace.phaseRiskMultiplierMin,
    searchSpace.phaseRiskMultiplierMax,
    random,
    scale,
  ),
  middleGameRiskMultiplier: _mutatedRange(
    parent.middleGameRiskMultiplier,
    searchSpace.phaseRiskMultiplierMin,
    searchSpace.phaseRiskMultiplierMax,
    random,
    scale,
  ),
  lateGameRiskMultiplier: _mutatedRange(
    parent.lateGameRiskMultiplier,
    searchSpace.phaseRiskMultiplierMin,
    searchSpace.phaseRiskMultiplierMax,
    random,
    scale,
  ),
  pijolScarcityWeight: _mutated(
    parent.pijolScarcityWeight,
    searchSpace.pijolScarcityWeightMax,
    random,
    scale,
  ),
  figureOpportunityCosts: {
    for (final group in PijolFigureGroup.values)
      group: _mutatedRange(
        parent.figureOpportunityCosts[group] ?? 0,
        searchSpace.figureOpportunityCostMin,
        searchSpace.figureOpportunityCostMax,
        random,
        scale,
      ),
  },
  schoolFaceOpportunityCosts: {
    for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++)
      face: _mutated(
        parent.schoolFaceOpportunityCosts[face] ?? 0,
        searchSpace.schoolFaceOpportunityCostMax,
        random,
        scale,
      ),
  },
  schoolOpeningFaceCosts: {
    for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++)
      face: _mutatedRange(
        parent.schoolOpeningFaceCosts[face] ?? 0,
        searchSpace.schoolOpeningFaceCostMin,
        searchSpace.schoolOpeningFaceCostMax,
        random,
        scale,
      ),
  },
  futureFieldValueWeight: _mutated(
    parent.futureFieldValueWeight,
    searchSpace.futureFieldValueWeightMax,
    random,
    scale,
  ),
  schoolBonusTargetWeight: _mutated(
    parent.schoolBonusTargetWeight,
    searchSpace.schoolBonusTargetWeightMax,
    random,
    scale,
  ),
  perfectColumnProgressWeight: _mutated(
    parent.perfectColumnProgressWeight,
    searchSpace.perfectColumnProgressWeightMax,
    random,
    scale,
  ),
  schoolPointWeight: _mutated(
    parent.schoolPointWeight,
    searchSpace.schoolPointWeightMax,
    random,
    scale,
  ),
  schoolNegativePenaltyWeight: _mutated(
    parent.schoolNegativePenaltyWeight,
    searchSpace.schoolNegativePenaltyWeightMax,
    random,
    scale,
  ),
  figureCompletionValueWeight: _mutated(
    parent.figureCompletionValueWeight,
    searchSpace.figureCompletionValueWeightMax,
    random,
    scale,
  ),
  rareFigureChaseWeight: _mutated(
    parent.rareFigureChaseWeight,
    searchSpace.rareFigureChaseWeightMax,
    random,
    scale,
  ),
  straightChaseWeight: _mutated(
    parent.straightChaseWeight,
    searchSpace.straightChaseWeightMax,
    random,
    scale,
  ),
  figureSpecificOpportunityCosts: parent.figureSpecificOpportunityCosts.isEmpty
      ? const {}
      : {
          for (final figure in Figure.values)
            figure: _mutatedRange(
              parent.figureSpecificOpportunityCosts[figure] ?? 0,
              searchSpace.figureSpecificOpportunityCostMin,
              searchSpace.figureSpecificOpportunityCostMax,
              random,
              scale,
            ),
        },
  pijolGroupCosts: {
    for (final group in PijolFigureGroup.values)
      group: _mutated(
        parent.pijolGroupCosts[group] ?? 0,
        searchSpace.pijolGroupCostMax,
        random,
        scale,
      ),
  },
);

double _mutated(double value, double maximum, Random random, double scale) {
  final delta = (random.nextDouble() * 2 - 1) * maximum * scale;
  return (value + delta).clamp(0, maximum).toDouble();
}

double _randomInRange(Random random, double minimum, double maximum) =>
    minimum + random.nextDouble() * (maximum - minimum);

double _mutatedRange(
  double value,
  double minimum,
  double maximum,
  Random random,
  double scale,
) => (value + (random.nextDouble() * 2 - 1) * (maximum - minimum) * scale)
    .clamp(minimum, maximum)
    .toDouble();

double _jsonDouble(Map<String, dynamic> json, String key, double fallback) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is! num) {
    throw FormatException('$key must be a number.');
  }
  return value.toDouble();
}
