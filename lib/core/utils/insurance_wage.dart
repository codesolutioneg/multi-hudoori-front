const employeeInsuranceShareRate = 0.11;

double insuranceWageFromShare(num? share) {
  final n = share?.toDouble() ?? 0;
  if (n <= 0) return 0;
  return ((n / employeeInsuranceShareRate) * 100).round() / 100;
}
