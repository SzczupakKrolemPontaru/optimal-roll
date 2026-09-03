import '../domain/figures.dart';

class AdvisorWeights {
  final double openingColumnValue;
  final double chanceCostEarly;
  final double chanceCostLate;
  final double pijolBaseCost;
  final double perfectColumnRiskCost;
  final Map<Figure, double> fieldOpportunityCosts;

  const AdvisorWeights({
    this.openingColumnValue = 8,
    this.chanceCostEarly = 10,
    this.chanceCostLate = 2,
    this.pijolBaseCost = 15,
    this.perfectColumnRiskCost = 40,
    this.fieldOpportunityCosts = const {},
  });
}
