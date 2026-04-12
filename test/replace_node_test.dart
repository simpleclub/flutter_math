// Regression tests for SyntaxTree.replaceNode.
//
// Before the fix, replaceNode built a `List<GreenNode?>` and passed it to
// the concrete overrides of `updateChildren`, which narrow the parameter
// type in every subclass (EquationRowNode wants List<GreenNode>, FracNode
// wants List<EquationRowNode>, etc.). This produced a runtime _TypeError
// on virtually any in-tree mutation. These tests cover the three parent
// shapes exhaustively: an EquationRowNode parent, a FracNode parent, and a
// MultiscriptsNode parent (nullable-slot case).

import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';

SyntaxTree _parse(String tex) =>
    SyntaxTree(greenRoot: TexParser(tex, const TexParserSettings()).parse());

void main() {
  group('SyntaxTree.replaceNode', () {
    test('replaces a direct child of EquationRowNode', () {
      final tree = _parse(r'x + y');
      final root = tree.root;
      // Find the first non-null red child — on `x + y` it will be the
      // SymbolNode for `x`.
      final firstChild = root.children.firstWhere((c) => c != null)!;
      expect(firstChild.value, isA<SymbolNode>());

      final replacement = SymbolNode(symbol: 'z');
      final updated = tree.replaceNode(firstChild, replacement);

      // The root row should still have the same number of children,
      // with the first one replaced.
      expect(updated.greenRoot, isA<EquationRowNode>());
      final newFirst = updated.greenRoot.children.first;
      expect(newFirst, isA<SymbolNode>());
      expect((newFirst as SymbolNode).symbol, 'z');
      expect(updated.greenRoot.children.length,
          tree.greenRoot.children.length);
    });

    test('replaces the numerator of a FracNode', () {
      final tree = _parse(r'\frac{1}{2}');
      // Walk the red tree: root -> FracNode -> numerator (EquationRowNode)
      final fracRed = tree.root.children.firstWhere((c) => c != null)!;
      expect(fracRed.value, isA<FracNode>());
      final numeratorRed = fracRed.children.firstWhere((c) => c != null)!;
      expect(numeratorRed.value, isA<EquationRowNode>());

      final replacement = EquationRowNode(
        children: [SymbolNode(symbol: '9')],
      );
      final updated = tree.replaceNode(numeratorRed, replacement);

      final newFrac = updated.greenRoot.children.first as FracNode;
      final newNumLeaf = newFrac.numerator.children.first as SymbolNode;
      expect(newNumLeaf.symbol, '9');
      // Denominator must be untouched.
      final denomLeaf = newFrac.denominator.children.first as SymbolNode;
      expect(denomLeaf.symbol, '2');
    });

    test('replaces the superscript slot of a MultiscriptsNode (nullable)', () {
      final tree = _parse(r'x^{2}');
      final multiRed = tree.root.children.firstWhere((c) => c != null)!;
      expect(multiRed.value, isA<MultiscriptsNode>());
      // Children of MultiscriptsNode are [base, sub, sup, presub, presup] —
      // many of which are null. The non-null ones here should be base & sup.
      final nonNullChildren =
          multiRed.children.whereType<SyntaxNode>().toList();
      expect(nonNullChildren.length, greaterThanOrEqualTo(2));

      // Locate the sup slot — it's the one whose green value contains the `2`.
      final supRed = nonNullChildren.firstWhere((c) {
        final row = c.value as EquationRowNode;
        return row.children.any(
            (x) => x is SymbolNode && x.symbol == '2');
      });

      final replacement = EquationRowNode(
        children: [SymbolNode(symbol: '7')],
      );
      final updated = tree.replaceNode(supRed, replacement);

      final newMulti = updated.greenRoot.children.first as MultiscriptsNode;
      expect(newMulti.sup, isNotNull);
      final newSupLeaf = newMulti.sup!.children.first as SymbolNode;
      expect(newSupLeaf.symbol, '7');
      // Base is untouched.
      final newBaseLeaf = newMulti.base.children.first as SymbolNode;
      expect(newBaseLeaf.symbol, 'x');
    });

    test('replacing the root wraps in an EquationRowNode', () {
      final tree = _parse(r'\frac{1}{2}');
      final replacement = SymbolNode(symbol: 'q');
      final updated = tree.replaceNode(tree.root, replacement);
      // A LeafNode replacement at the root must be wrapped.
      expect(updated.greenRoot, isA<EquationRowNode>());
      expect(updated.greenRoot.children.length, 1);
      expect((updated.greenRoot.children.first as SymbolNode).symbol, 'q');
    });
  });
}
