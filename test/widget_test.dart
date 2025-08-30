import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sliceofgourmet/app.dart';

void main() {
  testWidgets('app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SliceOfGourmetApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
