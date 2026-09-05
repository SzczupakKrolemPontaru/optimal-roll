import '../domain/figures.dart';

class AdvisorWeights {
  final double openingColumnValue;
  final double chanceCostEarly;
  final double chanceCostLate;
  final double pijolBaseCost;
  final double perfectColumnRiskCost;
  final double schoolBonusProgressWeight;
  final double schoolCompletionValue;
  final double futureFieldValueWeight;
  final double earlyGameRiskMultiplier;
  final double middleGameRiskMultiplier;
  final double lateGameRiskMultiplier;
  final double pijolScarcityWeight;
  final Map<Figure, double> fieldOpportunityCosts;
  final Map<int, double> schoolFaceOpportunityCosts;
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
    futureFieldValueWeight: 0,
    earlyGameRiskMultiplier: 1,
    middleGameRiskMultiplier: 1,
    lateGameRiskMultiplier: 1,
    pijolScarcityWeight: 0,
    fieldOpportunityCosts: {},
    schoolFaceOpportunityCosts: {},
    pijolFieldCosts: {},
  );

  /// Earlier adopted simulation-calibrated profile, retained for comparison.
  static const candidateV3 = AdvisorWeights(
    openingColumnValue: 22.508624280927165,
    chanceCostEarly: 45,
    chanceCostLate: 19.42040979213369,
    pijolBaseCost: 3.9065286946405724,
    perfectColumnRiskCost: 150.36227752446024,
    schoolBonusProgressWeight: 4.8035137570367406,
    schoolCompletionValue: 2.390856021180171,
    futureFieldValueWeight: 0,
    earlyGameRiskMultiplier: 1,
    middleGameRiskMultiplier: 1,
    lateGameRiskMultiplier: 1,
    pijolScarcityWeight: 0,
    fieldOpportunityCosts: {},
    schoolFaceOpportunityCosts: {},
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
    this.openingColumnValue = 36.64490059669705,
    this.chanceCostEarly = 32.385866293107256,
    this.chanceCostLate = 27.4009005750395,
    this.pijolBaseCost = 0,
    this.perfectColumnRiskCost = 30.585530569306638,
    this.schoolBonusProgressWeight = 4.211398428698021,
    this.schoolCompletionValue = 0,
    this.futureFieldValueWeight = 0,
    this.earlyGameRiskMultiplier = 0.9187242999670457,
    this.middleGameRiskMultiplier = 0.9530341014900772,
    this.lateGameRiskMultiplier = 0.7810287296831079,
    this.pijolScarcityWeight = 0,
    this.fieldOpportunityCosts = const {
      Figure.PAIR: 7.3976025556240295,
      Figure.TWO_PAIRS: 7.3976025556240295,
      Figure.THREE_OF_A_KIND: 7.3976025556240295,
      Figure.FOUR_OF_A_KIND: 7.3976025556240295,
      Figure.GENERAL: 0,
      Figure.MARSHAL: 0,
      Figure.THREE_PAIRS: 0,
      Figure.TWO_TRIPLES: 0,
      Figure.FOUR_PLUS_TWO: 0,
      Figure.FULL_HOUSE: 0,
      Figure.SMALL_STRAIGHT: 1.9838911097204304,
      Figure.BIG_STRAIGHT: 1.9838911097204304,
      Figure.GREAT_STRAIGHT: 1.9838911097204304,
      Figure.EVEN: 3.53479505877312,
      Figure.ODD: 3.53479505877312,
      Figure.SMALL: 0,
      Figure.CHANCE: 3.0595451728387917,
    },
    this.schoolFaceOpportunityCosts = const {},
    this.pijolFieldCosts = const {
      Figure.PAIR: 20.242224450845875,
      Figure.TWO_PAIRS: 20.242224450845875,
      Figure.THREE_OF_A_KIND: 20.242224450845875,
      Figure.FOUR_OF_A_KIND: 20.242224450845875,
      Figure.GENERAL: 0,
      Figure.MARSHAL: 0,
      Figure.THREE_PAIRS: 0,
      Figure.TWO_TRIPLES: 0,
      Figure.FOUR_PLUS_TWO: 0,
      Figure.FULL_HOUSE: 0,
      Figure.SMALL_STRAIGHT: 95.10288177416719,
      Figure.BIG_STRAIGHT: 95.10288177416719,
      Figure.GREAT_STRAIGHT: 95.10288177416719,
      Figure.EVEN: 66.99495774304121,
      Figure.ODD: 66.99495774304121,
      Figure.SMALL: 11.038769455304395,
      Figure.CHANCE: 150.96817083447124,
    },
  });
}
