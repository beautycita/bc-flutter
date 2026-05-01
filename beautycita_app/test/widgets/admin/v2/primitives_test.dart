// Anchor + smoke tests for admin v2 primitives.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beautycita/widgets/admin/v2/tokens.dart';
import 'package:beautycita/widgets/admin/v2/layout/card.dart';
import 'package:beautycita/widgets/admin/v2/layout/list_row.dart';
import 'package:beautycita/widgets/admin/v2/layout/empty_state.dart';
import 'package:beautycita/widgets/admin/v2/data_viz/kpi_tile.dart';
import 'package:beautycita/widgets/admin/v2/action/action_button.dart';
import 'package:beautycita/widgets/admin/v2/action/confirm_sheet.dart';
import 'package:beautycita/widgets/admin/v2/action/step_up_sheet.dart';
import 'package:beautycita/widgets/admin/v2/feedback/audit_indicator.dart';
import 'package:beautycita/widgets/admin/v2/shell/permission_chip.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  test('AdminV2Tokens spacing constants', () {
    expect(AdminV2Tokens.spacingMD, 16.0);
    expect(AdminV2Tokens.minTapHeight, 44.0);
  });

  testWidgets('AdminCard renders title + child', (tester) async {
    await tester.pumpWidget(_wrap(
      const AdminCard(title: 'Title', child: Text('child')),
    ));
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('child'), findsOneWidget);
  });

  testWidgets('AdminCardSkeleton renders', (tester) async {
    await tester.pumpWidget(_wrap(const AdminCardSkeleton()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AdminListRow shows em-dash for null value', (tester) async {
    await tester.pumpWidget(_wrap(
      const AdminListRow(label: 'L', value: null),
    ));
    expect(find.text('L'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('AdminListRow editable shows edit pencil', (tester) async {
    await tester.pumpWidget(_wrap(
      AdminListRow(label: 'L', value: 'v', editable: true, onEdit: () {}),
    ));
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('AdminEmptyState — loading shows spinner', (tester) async {
    await tester.pumpWidget(_wrap(const AdminEmptyState(kind: AdminEmptyKind.loading)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AdminEmptyState — error shows retry when action passed', (tester) async {
    var called = false;
    await tester.pumpWidget(_wrap(AdminEmptyState(
      kind: AdminEmptyKind.error,
      body: 'boom',
      action: 'Reintentar',
      onAction: () => called = true,
    )));
    expect(find.text('boom'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(called, isTrue);
  });

  testWidgets('AdminEmptyState — no permission renders lock icon', (tester) async {
    await tester.pumpWidget(_wrap(const AdminEmptyState(kind: AdminEmptyKind.noPermission)));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('AdminKpiTile renders value + unit + delta', (tester) async {
    await tester.pumpWidget(_wrap(
      const AdminKpiTile(label: 'Revenue', value: '1234', unit: 'MXN', deltaHint: '+12%', deltaPositive: true),
    ));
    expect(find.text('Revenue'), findsOneWidget);
    expect(find.text('+12%'), findsOneWidget);
  });

  testWidgets('AdminActionButton — primary fires onPressed', (tester) async {
    var fired = false;
    await tester.pumpWidget(_wrap(
      AdminActionButton(label: 'Go', onPressed: () => fired = true),
    ));
    await tester.tap(find.text('Go'));
    expect(fired, isTrue);
  });

  testWidgets('AdminActionButton — loading shows spinner not label', (tester) async {
    await tester.pumpWidget(_wrap(
      AdminActionButton(label: 'Go', isLoading: true, onPressed: () {}),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Go'), findsNothing);
  });

  testWidgets('AdminActionButton — destructive variant uses red', (tester) async {
    await tester.pumpWidget(_wrap(
      AdminActionButton(label: 'Del', variant: AdminActionVariant.destructive, onPressed: () {}),
    ));
    expect(find.text('Del'), findsOneWidget);
  });

  testWidgets('AdminActionButton — requiresStepUp shows lock badge', (tester) async {
    await tester.pumpWidget(_wrap(
      AdminActionButton(label: 'Sensitive', requiresStepUp: true, onPressed: () {}),
    ));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('AdminConfirmSheet returns reason on accept', (tester) async {
    String? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              captured = await AdminConfirmSheet.show(
                ctx,
                title: 'T',
                body: 'B',
                acceptVerb: 'Yes',
                requireReason: true,
                minReasonLength: 3,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'reasoning');
    await tester.pump();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(captured, 'reasoning');
  });

  testWidgets('AdminPermissionChip renders all states', (tester) async {
    for (final s in AdminPermissionState.values) {
      await tester.pumpWidget(_wrap(AdminPermissionChip(state: s)));
      expect(find.byType(AdminPermissionChip), findsOneWidget);
    }
  });

  test('AdminStepUpSheet symbol exists', () {
    expect(AdminStepUpSheet, isNotNull);
  });

  test('AdminAuditIndicator symbol exists', () {
    expect(AdminAuditIndicator, isNotNull);
  });
}
