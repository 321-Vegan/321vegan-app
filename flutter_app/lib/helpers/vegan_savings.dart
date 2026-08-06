/// Estimated impact (animals spared, CO2, forest, water) of being vegan
/// since [targetTime], in the units keyed by [HomeStat.savingsKey]
/// (widgets/homepage/stat_card.dart). Shared by the Dashboard's stat cards
/// and the vegan-anniversary popup so both read the same constants.
Map<String, int> computeSavings(DateTime? targetTime) {
  const double animalPer = 1.3;
  const double co2Per = 9.0;
  const double waterPer = 2.271;
  const double forestPer = 2.7;

  Duration duration = Duration.zero;
  if (targetTime != null) {
    duration = DateTime.now().difference(targetTime);
  }
  final double days = duration.inMinutes / 1440.0;

  return {
    'animalUnit': (days * animalPer).toInt(),
    'co2Unit': (days * co2Per).toInt(),
    'waterUnit': (days * waterPer).toInt(),
    'forestUnit': (days * forestPer).toInt(),
  };
}
