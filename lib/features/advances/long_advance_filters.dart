enum LongAdvanceRepaymentFilter { all, fullyRepaid, outstanding }

enum LongAdvanceEmployeeFilter { all, active, archived }

double longAdvanceRemainingAmount(Map<String, dynamic> advance) {
  final value = advance['remainingAmount'];
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double _longAdvanceAmount(Map<String, dynamic> advance, String key) {
  final value = advance[key];
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

({double paid, double remaining}) longAdvanceActiveTotals(
  Iterable<Map<String, dynamic>> advances,
) {
  var paid = 0.0;
  var remaining = 0.0;
  for (final advance in advances) {
    if (advance['state']?.toString() != 'running') continue;
    paid += _longAdvanceAmount(advance, 'paidAmount');
    remaining += longAdvanceRemainingAmount(advance);
  }
  return (paid: paid, remaining: remaining);
}

bool longAdvanceMatchesFilters(
  Map<String, dynamic> advance, {
  String query = '',
  String? state,
  LongAdvanceRepaymentFilter repayment = LongAdvanceRepaymentFilter.all,
  LongAdvanceEmployeeFilter employee = LongAdvanceEmployeeFilter.all,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isNotEmpty) {
    final code = advance['employeeCode']?.toString().toLowerCase() ?? '';
    final name = advance['employeeName']?.toString().toLowerCase() ?? '';
    if (!code.contains(normalizedQuery) && !name.contains(normalizedQuery)) {
      return false;
    }
  }

  final advanceState = advance['state']?.toString() ?? '';
  if (state != null && advanceState != state) {
    return false;
  }

  final isArchived = advance['employeeActive'] == false;
  if (employee == LongAdvanceEmployeeFilter.active && isArchived) {
    return false;
  }
  if (employee == LongAdvanceEmployeeFilter.archived && !isArchived) {
    return false;
  }

  if (repayment == LongAdvanceRepaymentFilter.all) {
    return true;
  }
  if (advanceState == 'cancelled') {
    return false;
  }

  final remaining = longAdvanceRemainingAmount(advance);
  return repayment == LongAdvanceRepaymentFilter.fullyRepaid
      ? remaining <= 0.01
      : remaining > 0.01;
}
