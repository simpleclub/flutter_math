import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

/// Matrix-like environments without any content have no columns. The horizontal
/// layout used to read `colPos[cols - 1]` / `colWidths[cols - 1]` unconditionally
/// and threw `RangeError (index): Invalid value: Valid value range is empty: -1`
/// from `performLayout()` (issue #98).
void main() {
  const emptyEnvironments = [
    r'\begin{matrix} \end{matrix}',
    r'\begin{pmatrix} \end{pmatrix}',
    r'\begin{bmatrix} \end{bmatrix}',
    r'\begin{Bmatrix} \end{Bmatrix}',
    r'\begin{vmatrix} \end{vmatrix}',
    r'\begin{Vmatrix} \end{Vmatrix}',
    r'\frac{\begin{pmatrix} \end{pmatrix}}{2}',
    r'\left( \begin{matrix} \end{matrix} \right)',
    r'x + \begin{matrix} \end{matrix} + y',
  ];

  for (final tex in emptyEnvironments) {
    testWidgets('lays out without throwing: $tex', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Math.tex(tex, mathStyle: MathStyle.display),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(Math));
      expect(size.width.isFinite && size.height.isFinite, isTrue);
    });
  }

  testWidgets('matrix with columns is unchanged', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Math.tex(
              r'\begin{pmatrix} a & b \\ c & d \end{pmatrix}',
              mathStyle: MathStyle.display,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(Math));
    expect(size.width, greaterThan(20));
    expect(size.height, greaterThan(20));
  });
}
