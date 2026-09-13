import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('/hr/shift-assignments resolves to assignments page', (tester) async {
    final router = GoRouter(
      initialLocation: '/hr/shift-assignments',
      routes: [
        ShellRoute(
          builder: (_, __, child) => Scaffold(body: child),
          routes: [
            GoRoute(path: '/hr/shifts', builder: (_, __) => const Text('shifts')),
            GoRoute(
              path: '/hr/shift-grid',
              builder: (_, __) => const Text('grid'),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, __) => const Text('grid-detail'),
                ),
              ],
            ),
            GoRoute(
              path: '/hr/shift-assignments',
              builder: (_, __) => const Text('assignments-page'),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('assignments-page'), findsOneWidget);
    expect(router.state.matchedLocation, '/hr/shift-assignments');
  });
}
