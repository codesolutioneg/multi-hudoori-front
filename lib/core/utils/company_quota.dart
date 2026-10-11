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

/// Direct-parent seat pool for a child company (`parentPool` from admin companies API).
class ParentPoolSnapshot {
  const ParentPoolSnapshot({
    required this.parentCompanyId,
    required this.parentMaxEmployees,
    required this.parentMaxUsers,
    required this.siblingsAllocatedEmployees,
    required this.siblingsAllocatedUsers,
    required this.remainingEmployees,
    required this.remainingUsers,
  });

  final String parentCompanyId;
  final int? parentMaxEmployees;
  final int? parentMaxUsers;
  final int siblingsAllocatedEmployees;
  final int siblingsAllocatedUsers;
  final int? remainingEmployees;
  final int? remainingUsers;

  factory ParentPoolSnapshot.fromJson(Map<String, dynamic>? json) {
    int? asInt(Object? v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
    final j = json ?? const {};
    return ParentPoolSnapshot(
      parentCompanyId: j['parentCompanyId']?.toString() ?? '',
      parentMaxEmployees: asInt(j['parentMaxEmployees']),
      parentMaxUsers: asInt(j['parentMaxUsers']),
      siblingsAllocatedEmployees: asInt(j['siblingsAllocatedEmployees']) ?? 0,
      siblingsAllocatedUsers: asInt(j['siblingsAllocatedUsers']) ?? 0,
      remainingEmployees: asInt(j['remainingEmployees']),
      remainingUsers: asInt(j['remainingUsers']),
    );
  }
}
