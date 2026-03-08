import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ast/options.dart';
import '../ast/style.dart';
import '../ast/syntax_tree.dart';
import '../ast/tex_break.dart';
import '../parser/tex/parse_error.dart';
import '../parser/tex/parser.dart';
import '../parser/tex/settings.dart';
import 'exception.dart';
import 'mode.dart';
import 'selectable.dart';

/// Signature for rendering an alternative widget when parsing or building fails.
typedef OnErrorFallback = Widget Function(FlutterMathException errmsg);

/// Static, non-selectable widget for equations.
///
/// Use [Math] when you only need rendering and do not need selection or copy
/// support. Compared to [SelectableMath], it has less overhead and is usually
/// the better default for read-only equations.
///
/// Example:
///
/// ```dart
/// Math.tex(
///   r'\frac a b\sqrt[3]{n}',
///   mathStyle: MathStyle.display,
///   textStyle: const TextStyle(fontSize: 42),
/// )
/// ```
class Math extends StatelessWidget {
  /// Creates a math widget from an already parsed [SyntaxTree].
  ///
  /// Provide either a built [ast] or a [parseError].
  ///
  /// Most applications should prefer [Math.tex], which parses a TeX string and
  /// returns a ready-to-use widget.
  const Math({
    Key? key,
    this.ast,
    this.mathStyle = MathStyle.display,
    this.logicalPpi,
    this.onErrorFallback = defaultOnErrorFallback,
    this.options,
    this.parseError,
    this.textScaleFactor,
    this.textStyle,
  })  : assert(ast != null || parseError != null),
        super(key: key);

  /// The equation to display.
  ///
  /// It can be null only when [parseError] is not null.
  final SyntaxTree? ast;

  /// {@template flutter_math_fork.widgets.math.mathStyle}
  /// Layout style for the rendered equation.
  ///
  /// Choose [MathStyle.display] for displayed equations and [MathStyle.text]
  /// for inline equations.
  ///
  /// Ignored when [options] is provided.
  /// {@endtemplate}
  final MathStyle mathStyle;

  /// {@template flutter_math_fork.widgets.math.logicalPpi}
  /// {@macro flutter_math_fork.math_options.logicalPpi}
  ///
  /// If set to null, the effective [logicalPpi] will scale with
  /// [TextStyle.fontSize]. You can obtain the default scaled value by
  /// [MathOptions.defaultLogicalPpiFor].
  ///
  /// Ignored when [options] is provided.
  ///
  /// {@endtemplate}
  final double? logicalPpi;

  /// {@template flutter_math_fork.widgets.math.onErrorFallback}
  /// Fallback widget used when parsing or building fails.
  ///
  /// Called when:
  ///
  /// * a stored parse exception is already present.
  /// * [SyntaxTree.buildWidget] throws an error.
  ///
  /// This callback runs during build, so it should stay cheap and avoid side
  /// effects.
  /// {@endtemplate}
  final OnErrorFallback onErrorFallback;

  /// {@template flutter_math_fork.widgets.math.options}
  /// Complete rendering options for the equation.
  ///
  /// When provided, these options take precedence over [mathStyle],
  /// [textStyle], and [logicalPpi].
  /// {@endtemplate}
  final MathOptions? options;

  /// {@template flutter_math_fork.widgets.math.parseError}
  /// Errors generated during parsing.
  ///
  /// If non-null, [onErrorFallback] is shown instead of rendering math.
  /// {@endtemplate}
  final ParseException? parseError;

  /// Multiplier applied to the effective text size before rendering.
  ///
  /// When null, the equation follows the ambient [MediaQuery] text scaling.
  final double? textScaleFactor;

  /// {@template flutter_math_fork.widgets.math.textStyle}
  /// Base text style used to size and color the rendered equation.
  ///
  /// [TextStyle.fontSize] controls the overall equation size. Text weight,
  /// shape, color, and inherited font settings also affect rendering. Text
  /// inside `\text{...}` uses the same effective style and locale-aware text
  /// shaping.
  ///
  /// If null, [DefaultTextStyle] from the current context is used.
  ///
  /// Ignored when [options] is provided.
  /// {@endtemplate}
  final TextStyle? textStyle;

  /// Creates a math widget from a TeX [expression].
  ///
  /// {@template flutter_math_fork.widgets.math.tex_builder}
  /// The expression is parsed with [settings] and then rendered using either
  /// [options] or the simpler [mathStyle] and [textStyle] inputs.
  ///
  /// If parsing fails or a render-time build error occurs,
  /// [onErrorFallback] is displayed.
  ///
  /// Example:
  ///
  /// ```dart
  /// Math.tex(
  ///   r'\text{বাংলা } + x^2 = 25',
  ///   mathStyle: MathStyle.text,
  /// )
  /// ```
  /// {@endtemplate}
  ///
  /// See also:
  ///
  /// * [Math.mathStyle]
  /// * [Math.textStyle]
  factory Math.tex(
    String expression, {
    Key? key,
    MathStyle mathStyle = MathStyle.display,
    TextStyle? textStyle,
    OnErrorFallback onErrorFallback = defaultOnErrorFallback,
    TexParserSettings settings = const TexParserSettings(),
    double? textScaleFactor,
    MathOptions? options,
  }) {
    SyntaxTree? ast;
    ParseException? parseError;
    try {
      ast = SyntaxTree(greenRoot: TexParser(expression, settings).parse());
    } on ParseException catch (e) {
      parseError = e;
    } on Object catch (e) {
      parseError = ParseException('Unsanitized parse exception detected: $e.'
          'Please report this error with corresponding input.');
    }
    return Math(
      key: key,
      ast: ast,
      parseError: parseError,
      options: options,
      onErrorFallback: onErrorFallback,
      mathStyle: mathStyle,
      textScaleFactor: textScaleFactor,
      textStyle: textStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (parseError != null) {
      return onErrorFallback(parseError!);
    }

    var options = this.options;
    if (options == null) {
      var effectiveTextStyle = textStyle;
      if (effectiveTextStyle == null || effectiveTextStyle.inherit) {
        effectiveTextStyle =
            DefaultTextStyle.of(context).style.merge(textStyle);
      }
      if (MediaQuery.boldTextOf(context)) {
        effectiveTextStyle = effectiveTextStyle
            .merge(const TextStyle(fontWeight: FontWeight.bold));
      }

      final baseFontSize =
          effectiveTextStyle.fontSize ?? MathOptions.defaultFontSize;
      final scaledFontSize = this.textScaleFactor != null
          ? baseFontSize * this.textScaleFactor!
          : MediaQuery.textScalerOf(context).scale(baseFontSize);
      final effectiveColor = effectiveTextStyle.color ??
          DefaultTextStyle.of(context).style.color ??
          Colors.black;

      options = MathOptions(
        style: mathStyle,
        fontSize: scaledFontSize,
        mathFontOptions: effectiveTextStyle.fontWeight != FontWeight.normal &&
                effectiveTextStyle.fontWeight != null
            ? FontOptions(fontWeight: effectiveTextStyle.fontWeight!)
            : null,
        textModeTextStyle: effectiveTextStyle,
        textLocale: Localizations.maybeLocaleOf(context),
        logicalPpi: logicalPpi,
        color: effectiveColor,
      );
    }

    Widget child;

    try {
      child = ast!.buildWidget(options);
    } on BuildException catch (e) {
      return onErrorFallback(e);
    } on Object catch (e) {
      return onErrorFallback(
          BuildException('Unsanitized build exception detected: $e.'
              'Please report this error with corresponding input.'));
    }

    return Provider.value(
      value: FlutterMathMode.view,
      child: child,
    );
  }

  /// Default fallback used by [Math] and [SelectableMath].
  static Widget defaultOnErrorFallback(FlutterMathException error) =>
      SelectableText(error.messageWithType);

  /// Line breaking results using standard TeX-style line breaking.
  ///
  /// This function will return a list of `Math` widget along with a list of
  /// line breaking penalties.
  ///
  /// {@template flutter_math_fork.widgets.math.tex_break}
  ///
  /// This function will break the equation into pieces according to TeX spec
  /// **as much as possible** (some exceptions exist when `enforceNoBreak: true`
  /// ). Then, you can assemble the pieces in whatever way you like. The most
  /// simple way is to put the parts inside a `Wrap`.
  ///
  /// If you wish to implement a custom line breaking policy to manage the
  /// penalties, you can access the penalties in `BreakResult.penalties`. The
  /// values in `BreakResult.penalties` represent the line-breaking penalty
  /// generated at the right end of each `BreakResult.parts`. Note that
  /// `\nobreak` or `\penalty<number>=10000>` are left unbroken by default, you
  /// need to supply `enforceNoBreak: false` into `Math.texBreak` to expose
  /// those break points and their penalties.
  ///
  /// {@endtemplate}
  BreakResult<Math> texBreak({
    int relPenalty = 500,
    int binOpPenalty = 700,
    bool enforceNoBreak = true,
  }) {
    final ast = this.ast;
    if (ast == null || parseError != null) {
      return BreakResult(parts: [this], penalties: [10000]);
    }
    final astBreakResult = ast.texBreak(
      relPenalty: relPenalty,
      binOpPenalty: binOpPenalty,
      enforceNoBreak: enforceNoBreak,
    );
    return BreakResult(
      parts: astBreakResult.parts
          .map((part) => Math(
                ast: part,
                mathStyle: this.mathStyle,
                logicalPpi: this.logicalPpi,
                onErrorFallback: this.onErrorFallback,
                options: this.options,
                parseError: this.parseError,
                textScaleFactor: this.textScaleFactor,
                textStyle: this.textStyle,
              ))
          .toList(growable: false),
      penalties: astBreakResult.penalties,
    );
  }
}
