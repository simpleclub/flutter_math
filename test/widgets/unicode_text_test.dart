import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import '../load_fonts.dart';

void main() {
  setUpAll(loadKaTeXFonts);

  Finder richTextWithPlainText(String text) => find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == text,
      );

  testWidgets('renders unicode text inside text mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Math.tex(
            r'\text{試 বাংলা é}',
            textStyle: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(richTextWithPlainText('বাংলা'), findsOneWidget);
    expect(richTextWithPlainText('ব'), findsNothing);
  });

  testWidgets('renders arabic text inside text mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Math.tex(
            r'\text{العربية } + x^2 = 25',
            textStyle: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(richTextWithPlainText('العربية'), findsOneWidget);
    expect(richTextWithPlainText('ا'), findsNothing);
  });

  testWidgets('renders selectable arabic text inside text mode',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectableMath.tex(
            r'\text{العربية } + x^2 = 25',
            textStyle: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(richTextWithPlainText('العربية'), findsOneWidget);
    expect(richTextWithPlainText('ا'), findsNothing);
  });

  testWidgets('renders top-level unicode with non-strict settings',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Math.tex(
            '試 বাংলা é',
            settings: const TexParserSettings(strict: Strict.ignore),
            textStyle: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders top-level unicode with default settings',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Math.tex(
            '試 বাংলা é',
            textStyle: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders math and unicode text on the same line', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Math.tex(
            r'x^2 + \text{試 বাংলা é} + \alpha',
            textStyle: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(richTextWithPlainText('বাংলা'), findsOneWidget);
    expect(richTextWithPlainText('ব'), findsNothing);
  });

  testWidgets('renders math and raw unicode on the same line', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Math.tex(
            '試 + x^2 + বাংলা',
            settings: const TexParserSettings(strict: Strict.ignore),
            textStyle: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
