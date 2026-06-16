import 'package:adhan/adhan.dart';

CalculationMethod getMethodForCountry(String country) {
  final c = country.toLowerCase();

  if (c.contains('usa') || c.contains('united states') || c.contains('canada')) {
    return CalculationMethod.north_america; // ISNA
  }
  if (c.contains('pakistan') || c.contains('india') || c.contains('bangladesh') || c.contains('afghanistan')) {
    return CalculationMethod.karachi;
  }
  if (c.contains('saudi') || c.contains('arabia') || c.contains('yemen')) {
    return CalculationMethod.umm_al_qura;
  }
  if (c.contains('egypt') || c.contains('sudan') || c.contains('libya') || c.contains('africa')) {
    return CalculationMethod.egyptian;
  }
  if (c.contains('singapore') || c.contains('malaysia') || c.contains('indonesia')) {
    return CalculationMethod.singapore;
  }
  if (c.contains('turkey')) {
    return CalculationMethod.turkey;
  }
  if (c.contains('dubai') || c.contains('uae') || c.contains('united arab emirates')) {
    return CalculationMethod.dubai;
  }
  if (c.contains('kuwait')) {
    return CalculationMethod.kuwait;
  }
  if (c.contains('qatar')) {
    return CalculationMethod.qatar;
  }
  if (c.contains('iran')) {
    return CalculationMethod.tehran;
  }

  // Default to MWL for Europe, Far East, and the rest of the world
  return CalculationMethod.muslim_world_league;
}

String getMethodName(CalculationMethod method) {
  switch (method) {
    case CalculationMethod.north_america:
      return 'ISNA (North America)';
    case CalculationMethod.karachi:
      return 'University of Islamic Sciences, Karachi';
    case CalculationMethod.umm_al_qura:
      return 'Umm Al-Qura University, Makkah';
    case CalculationMethod.egyptian:
      return 'Egyptian General Authority of Survey';
    case CalculationMethod.singapore:
      return 'MUIS (Singapore) / JAKIM';
    case CalculationMethod.turkey:
      return 'Diyanet (Turkey)';
    case CalculationMethod.dubai:
      return 'Dubai';
    case CalculationMethod.kuwait:
      return 'Kuwait';
    case CalculationMethod.qatar:
      return 'Qatar';
    case CalculationMethod.tehran:
      return 'Tehran';
    case CalculationMethod.muslim_world_league:
      return 'Muslim World League (MWL)';
    default:
      return 'Muslim World League (MWL)';
  }
}
