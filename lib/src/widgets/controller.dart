import 'package:flutter/widgets.dart';
import '../ast/syntax_tree.dart';
import '../utils/text_extension.dart';

class MathController extends ChangeNotifier {
  MathController({
    required SyntaxTree ast,
    TextSelection selection = const TextSelection.collapsed(offset: -1),
  })  : _ast = ast,
        _selection = selection;

  SyntaxTree _ast;
  SyntaxTree get ast => _ast;
  set ast(SyntaxTree value) {
    if (_ast != value) {
      _ast = value;
      // Preserve the selection across tree mutations, clamped to the new
      // tree's valid range. Required for editable-math widgets that need
      // the caret to survive insertions/deletions.
      _selection = sanitizeSelection(_ast, _selection);
      notifyListeners();
    }
  }

  TextSelection get selection => _selection;
  TextSelection _selection;
  set selection(TextSelection value) {
    if (_selection != value) {
      _selection = sanitizeSelection(ast, value);
      notifyListeners();
    }
  }

  TextSelection sanitizeSelection(SyntaxTree ast, TextSelection selection) {
    if (selection.end <= 0) return selection;
    return selection.constrainedBy(ast.root.range);
  }

  List<GreenNode> get selectedNodes =>
      ast.findSelectedNodes(selection.start, selection.end);
}
