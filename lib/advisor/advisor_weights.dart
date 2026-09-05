import '../domain/figures.dart';

class AdvisorWeights {
  final double openingColumnValue;
  final double chanceCostEarly;
  final double chanceCostLate;
  final double pijolBaseCost;
  final double perfectColumnRiskCost;
  final double schoolBonusProgressWeight;
  final double schoolCompletionValue;
  final Map<Figure, double> fieldOpportunityCosts;
  final Map<Figure, double> pijolFieldCosts;

  /// Weights used before the first statistically validated calibration.
  ///
  /// Kept as a reproducible baseline for future experiments. The unnamed
  /// constructor represents the currently adopted production profile.
  static const baselineV1 = AdvisorWeights(
    openingColumnValue: 8,
    chanceCostEarly: 10,
    chanceCostLate: 2,
    pijolBaseCost: 15,
    perfectColumnRiskCost: 40,
    schoolBonusProgressWeight: 0,
    schoolCompletionValue: 0,
    fieldOpportunityCosts: {},
    pijolFieldCosts: {},
  );

  /// First adopted simulation-calibrated profile.
  static const candidateV3 = AdvisorWeights(
    openingColumnValue: 22.508624280927165,
    chanceCostEarly: 45,
    chanceCostLate: 19.42040979213369,
    pijolBaseCost: 3.9065286946405724,
    perfectColumnRiskCost: 150.36227752446024,
    schoolBonusProgressWeight: 4.8035137570367406,
    schoolCompletionValue: 2.390856021180171,
    fieldOpportunityCosts: {},
    pijolFieldCosts: {
      Figure.PAIR: 91.19002870430332,
      Figure.TWO_PAIRS: 91.19002870430332,
      Figure.THREE_OF_A_KIND: 91.19002870430332,
      Figure.FOUR_OF_A_KIND: 91.19002870430332,
      Figure.GENERAL: 50.01381598755992,
      Figure.MARSHAL: 50.01381598755992,
      Figure.THREE_PAIRS: 5.575583598521824,
      Figure.TWO_TRIPLES: 5.575583598521824,
      Figure.FOUR_PLUS_TWO: 5.575583598521824,
      Figure.FULL_HOUSE: 5.575583598521824,
      Figure.SMALL_STRAIGHT: 97.78227797712131,
      Figure.BIG_STRAIGHT: 97.78227797712131,
      Figure.GREAT_STRAIGHT: 97.78227797712131,
      Figure.EVEN: 40.82731029587417,
      Figure.ODD: 40.82731029587417,
      Figure.SMALL: 19.265586378048482,
      Figure.CHANCE: 91.97612050144282,
    },
  );

  const AdvisorWeights({
    this.openingColumnValue = 34.31023154115867,
    this.chanceCostEarly = 47.513850050906086,
    this.chanceCostLate = 27.8088324989341,
    this.pijolBaseCost = 0,
    this.perfectColumnRiskCost = 55.08930141267315,
    this.schoolBonusProgressWeight = 5.422685406811303,
    this.schoolCompletionValue = 0,
    this.fieldOpportunityCosts = const {},
    this.pijolFieldCosts = const {
      Figure.PAIR: 67.69151281052419,
      Figure.TWO_PAIRS: 67.69151281052419,
      Figure.THREE_OF_A_KIND: 67.69151281052419,
      Figure.FOUR_OF_A_KIND: 67.69151281052419,
      Figure.GENERAL: 0.5921810962825909,
      Figure.MARSHAL: 0.5921810962825909,
      Figure.THREE_PAIRS: 38.482302546258836,
      Figure.TWO_TRIPLES: 38.482302546258836,
      Figure.FOUR_PLUS_TWO: 38.482302546258836,
      Figure.FULL_HOUSE: 38.482302546258836,
      Figure.SMALL_STRAIGHT: 60.07835004457932,
      Figure.BIG_STRAIGHT: 60.07835004457932,
      Figure.GREAT_STRAIGHT: 60.07835004457932,
      Figure.EVEN: 103.53239335627892,
      Figure.ODD: 103.53239335627892,
      Figure.SMALL: 11.490478938462099,
      Figure.CHANCE: 141.89136148249204,
    },
  });
}
