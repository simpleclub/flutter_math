import 'package:flutter/widgets.dart';

import '../../utils/unicode_literal.dart';
import '../options.dart';
import '../syntax_tree.dart';
import '../types.dart';

const _defaultTextFont = FontOptions();
const _katexTextFontFamilies = {
  'AMS',
  'Caligraphic',
  'Fraktur',
  'Main',
  'Math',
  'SansSerif',
  'Script',
  'Size1',
  'Size2',
  'Size3',
  'Size4',
  'Typewriter',
};

/// A shaped text run rendered as a single Flutter text paragraph.
class TextRunNode extends LeafNode {
  final String text;
  final FontOptions? overrideFont;
  final AtomType _leftType;
  final AtomType _rightType;

  TextRunNode({
    required this.text,
    FontOptions? overrideFont,
    AtomType leftType = AtomType.ord,
    AtomType rightType = AtomType.ord,
  })  : assert(text.isNotEmpty),
        overrideFont = overrideFont,
        _leftType = leftType,
        _rightType = rightType;

  @override
  Mode get mode => Mode.text;

  @override
  BuildResult buildWidget(
    MathOptions options,
    List<BuildResult?> childBuildResults,
  ) {
    final baseStyle = (options.textModeTextStyle ?? const TextStyle()).copyWith(
      color: options.color,
      fontSize: options.fontSize,
    );
    final explicitFont = overrideFont ?? options.textFontOptions;
    final effectiveFont = explicitFont ?? _defaultTextFont;

    return BuildResult(
      options: options,
      widget: RichText(
        textDirection: _resolveTextDirection(text),
        text: TextSpan(
          text: text,
          locale: options.textLocale,
          style: baseStyle.copyWith(
            fontFamily: baseStyle.fontFamily ??
                _resolveFontFamily(effectiveFont.fontFamily),
            fontWeight: explicitFont?.fontWeight ?? baseStyle.fontWeight,
            fontStyle: explicitFont?.fontShape ?? baseStyle.fontStyle,
          ),
        ),
        overflow: TextOverflow.visible,
        softWrap: false,
      ),
    );
  }

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      oldOptions.color != newOptions.color ||
      oldOptions.sizeMultiplier != newOptions.sizeMultiplier ||
      oldOptions.textFontOptions != newOptions.textFontOptions ||
      oldOptions.textModeTextStyle != newOptions.textModeTextStyle ||
      oldOptions.textLocale != newOptions.textLocale;

  @override
  AtomType get leftType => _leftType;

  @override
  AtomType get rightType => _rightType;

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'mode': mode.toString(),
      'text': unicodeLiteral(text),
      if (overrideFont != null) 'overrideFont': overrideFont.toString(),
      if (_leftType != AtomType.ord) 'leftType': _leftType.toString(),
      if (_rightType != AtomType.ord) 'rightType': _rightType.toString(),
    });

  String _resolveFontFamily(String fontFamily) {
    if (_katexTextFontFamilies.contains(fontFamily)) {
      return 'packages/flutter_math_fork/KaTeX_$fontFamily';
    }
    return fontFamily;
  }

  TextDirection? _resolveTextDirection(String text) {
    if (text.runes.any(_isRtlCodepoint)) {
      return TextDirection.rtl;
    }
    return null;
  }

  bool _isRtlCodepoint(int codepoint) =>
      (codepoint >= 0x0590 && codepoint <= 0x08FF) ||
      (codepoint >= 0xFB1D && codepoint <= 0xFDFF) ||
      (codepoint >= 0xFE70 && codepoint <= 0xFEFF);
}
