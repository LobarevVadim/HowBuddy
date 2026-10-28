import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/features/home/home_page.dart';
import 'package:hello/models/app_models.dart';

void main() {
  testWidgets('XP rebuilds do not refetch; account changes do', (tester) async {
    var requests = 0;
    Future<XpWeeklySummary> load(String _) {
      requests++;
      return Future.error(Exception('offline'));
    }

    Widget page(String account, double scale) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: XpTabPage(accountId: account, loadSummary: load),
      ),
    );
    await tester.pumpWidget(page('a', 1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(page('a', 1.2));
    await tester.pumpAndSettle();
    expect(requests, 1);
    await tester.pumpWidget(page('b', 1.2));
    await tester.pumpAndSettle();
    expect(requests, 2);
  });
}
