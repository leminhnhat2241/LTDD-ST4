// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nfc_write_app/main.dart';

void main() {
  testWidgets('Login screen shows for unauthenticated user', (WidgetTester tester) async {
    await tester.pumpWidget(const NfcWriterApp());

    expect(find.textContaining('Đăng nhập'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.widgetWithIcon(ElevatedButton, Icons.login), findsOneWidget);
  });
}
