/// Company SaaS seats as returned by the API (`quota` object). Null max = unlimited.
class CompanyQuota {
  const CompanyQuota({
    required this.employeesUsed,
    required this.employeesMax,
    required this.usersUsed,
    required this.usersMax,
  });

  final int employeesUsed;
  final int? employeesMax;
  final int usersUsed;
  final int? usersMax;

  bool get employeesFull => employeesMax != null && employeesUsed >= employeesMax!;
  bool get usersFull => usersMax != null && usersUsed >= usersMax!;

  factory CompanyQuota.fromJson(Map<String, dynamic>? json) {
    int? asInt(Object? v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
    final j = json ?? const {};
    return CompanyQuota(
      employeesUsed: asInt(j['employeesUsed']) ?? 0,
      employeesMax: asInt(j['employeesMax']),
      usersUsed: asInt(j['usersUsed']) ?? 0,
      usersMax: asInt(j['usersMax']),
    );
  }
}
