import 'package:biotime_app/features/advances/long_advance_filters.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> advance({
  String code = '100',
  String name = 'موظف',
  String state = 'running',
  double remaining = 100,
  bool active = true,
}) {
  return {
    'employeeCode': code,
    'employeeName': name,
    'state': state,
    'remainingAmount': remaining,
    'employeeActive': active,
  };
}

void main() {
  test('all filters include archived employee advances by default', () {
    expect(longAdvanceMatchesFilters(advance(active: false)), isTrue);
  });

  test('employee filter distinguishes active and archived employees', () {
    final archived = advance(active: false);
    expect(
      longAdvanceMatchesFilters(
        archived,
        employee: LongAdvanceEmployeeFilter.archived,
      ),
      isTrue,
    );
    expect(
      longAdvanceMatchesFilters(
        archived,
        employee: LongAdvanceEmployeeFilter.active,
      ),
      isFalse,
    );
  });

  test('repayment filter follows the backend one-cent tolerance', () {
    expect(
      longAdvanceMatchesFilters(
        advance(remaining: 0.01),
        repayment: LongAdvanceRepaymentFilter.fullyRepaid,
      ),
      isTrue,
    );
    expect(
      longAdvanceMatchesFilters(
        advance(remaining: 0.02),
        repayment: LongAdvanceRepaymentFilter.outstanding,
      ),
      isTrue,
    );
  });

  test('cancelled advances are not counted as debt or fully repaid', () {
    final cancelled = advance(state: 'cancelled', remaining: 100);
    expect(
      longAdvanceMatchesFilters(
        cancelled,
        repayment: LongAdvanceRepaymentFilter.outstanding,
      ),
      isFalse,
    );
    expect(
      longAdvanceMatchesFilters(
        cancelled,
        repayment: LongAdvanceRepaymentFilter.fullyRepaid,
      ),
      isFalse,
    );
  });

  test('search and state filters combine with repayment filters', () {
    final item = advance(
      code: '4638',
      name: 'محمد',
      state: 'done',
      remaining: 0,
      active: false,
    );
    expect(
      longAdvanceMatchesFilters(
        item,
        query: '4638',
        state: 'done',
        repayment: LongAdvanceRepaymentFilter.fullyRepaid,
        employee: LongAdvanceEmployeeFilter.archived,
      ),
      isTrue,
    );
    expect(longAdvanceMatchesFilters(item, query: 'غير موجود'), isFalse);
  });

  test('active totals sum only running advances', () {
    final totals = longAdvanceActiveTotals([
      advance(state: 'running', remaining: 100)..['paidAmount'] = 50,
      advance(state: 'running', remaining: 200)..['paidAmount'] = 25,
      advance(state: 'done', remaining: 0)..['paidAmount'] = 500,
      advance(state: 'draft', remaining: 80)..['paidAmount'] = 0,
    ]);
    expect(totals.paid, 75);
    expect(totals.remaining, 300);
  });
}
