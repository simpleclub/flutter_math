import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';

void testTexToMatchGoldenFile(
  String description,
  String expression, {
  String? location,
  double scale = 1,
}) {
  testWidgets(description, (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = Size(500 * scale, 300 * scale);
    tester.view.devicePixelRatio = 1.0;
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Math.tex(
                  expression,
                  options: MathOptions(
                    style: MathStyle.display,
                    fontSize: scale * MathOptions.defaultFontSize,
                  ),
                  onErrorFallback: (_) => throw _,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (Platform.isWindows) {
      // Android-specific code
      await expectLater(find.byKey(key),
          matchesGoldenFile(location ?? 'golden/${description.hashCode}.png'));
    }
  });
}

void testTexToRender(
  String description,
  String expression, [
  Future<void> Function(WidgetTester)? callback,
]) {
  testWidgets(description, (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Math.tex(
                  expression,
                  options: MathOptions(
                    fontSize: MathOptions.defaultFontSize,
                    style: MathStyle.display,
                  ),
                  onErrorFallback: (_) => throw _,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (callback != null) {
      await callback(tester);
    }
  });
}

void testTexToRenderLike(
    String description, String expression1, String expression2,
    [TexParserSettings settings = strictSettings]) {
  testWidgets(description, (WidgetTester tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Math.tex(
                  expression1,
                  options: MathOptions(
                    fontSize: MathOptions.defaultFontSize,
                    style: MathStyle.display,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final firstImage = await _captureWidgetImage(tester, key);

    final key2 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Math.tex(
                  expression2,
                  options: MathOptions(
                    fontSize: MathOptions.defaultFontSize,
                    style: MathStyle.display,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final secondImage = await _captureWidgetImage(tester, key2);

    expect(
      secondImage.width,
      firstImage.width,
      reason: 'Rendered width mismatch for "$description"',
    );
    expect(
      secondImage.height,
      firstImage.height,
      reason: 'Rendered height mismatch for "$description"',
    );
    expect(
      listEquals(secondImage.bytes, firstImage.bytes),
      isTrue,
      reason: 'Rendered pixels mismatch for "$description"',
    );
  });
}

Future<_CapturedImage> _captureWidgetImage(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final capturedImage = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    try {
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        throw StateError('Failed to capture image bytes for widget.');
      }
      return _CapturedImage(
        width: image.width,
        height: image.height,
        bytes: byteData.buffer.asUint8List(),
      );
    } finally {
      image.dispose();
    }
  });
  if (capturedImage == null) {
    throw StateError('Failed to capture image for widget.');
  }
  return capturedImage;
}

class _CapturedImage {
  const _CapturedImage({
    required this.width,
    required this.height,
    required this.bytes,
  });

  final int width;
  final int height;
  final Uint8List bytes;
}

const strictSettings = TexParserSettings(strict: Strict.error);
const nonstrictSettings = TexParserSettings(strict: Strict.ignore);

EquationRowNode getParsed(String expr,
        [TexParserSettings settings = const TexParserSettings()]) =>
    TexParser(expr, settings).parse();

String prettyPrintJson(Map<String, Object> a) =>
    JsonEncoder.withIndent('| ').convert(a);

_ToParse toParse([TexParserSettings settings = strictSettings]) =>
    _ToParse(settings);

class _ToParse extends Matcher {
  final TexParserSettings settings;

  _ToParse(this.settings);

  @override
  Description describe(Description description) =>
      description.add('a TeX string can be parsed with default settings');

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map matchState, bool verbose) {
    try {
      if (item is String) {
        TexParser(item, settings).parse();
        return super
            .describeMismatch(item, mismatchDescription, matchState, verbose);
      }
      return mismatchDescription.add('input is not a string');
    } on ParseException catch (e) {
      return mismatchDescription.add(e.message);
    } on Object catch (e) {
      return mismatchDescription.add(e.toString());
    }
  }

  @override
  bool matches(dynamic item, Map matchState) {
    try {
      if (item is String) {
        // ignore: unused_local_variable
        final res = TexParser(item, const TexParserSettings()).parse();
        // print(prettyPrintJson(res.toJson()));
        return true;
      }
      return false;
    } on ParseException catch (_) {
      return false;
    }
  }
}

_ToNotParse toNotParse([TexParserSettings settings = strictSettings]) =>
    _ToNotParse(settings);

class _ToNotParse extends Matcher {
  final TexParserSettings settings;

  _ToNotParse(this.settings);

  @override
  Description describe(Description description) =>
      description.add('a TeX string with parse errors');

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map matchState, bool verbose) {
    try {
      if (item is String) {
        // ignore: unused_local_variable
        final res = TexParser(item, settings).parse();
        return super
            .describeMismatch(item, mismatchDescription, matchState, verbose);
        // return mismatchDescription.add(prettyPrintJson(res.toJson()));
      }
      return mismatchDescription.add('input is not a string');
    } on ParseException catch (_) {
      return super
          .describeMismatch(item, mismatchDescription, matchState, verbose);
    }
  }

  @override
  bool matches(dynamic item, Map matchState) {
    try {
      if (item is String) {
        // ignore: unused_local_variable
        final res = TexParser(item, settings).parse();
        // print(prettyPrintJson(res.toJson()));
        return false;
      }
      return false;
    } on ParseException catch (_) {
      return true;
    }
  }
}

final toBuild = _ToBuild();

final toBuildStrict = _ToBuild(settings: strictSettings);

class _ToBuild extends Matcher {
  final MathOptions options;
  final TexParserSettings settings;

  _ToBuild({
    MathOptions? options,
    this.settings = nonstrictSettings,
  }) : this.options = options ?? MathOptions.displayOptions;

  @override
  Description describe(Description description) =>
      description.add('a TeX string can be built into widgets');

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map matchState, bool verbose) {
    try {
      if (item is String) {
        final ast = SyntaxTree(
          greenRoot: TexParser(item, settings).parse(),
        );
        ast.buildWidget(options);
        return super
            .describeMismatch(item, mismatchDescription, matchState, verbose);
      }
      return mismatchDescription.add('input is not a string');
    } on ParseException catch (e) {
      return mismatchDescription.add(e.message);
    } on Object catch (e) {
      return mismatchDescription.add(e.toString());
    }
  }

  @override
  bool matches(dynamic item, Map matchState) {
    try {
      if (item is String) {
        final ast = SyntaxTree(
          greenRoot: TexParser(item, settings).parse(),
        );
        ast.buildWidget(options);
        return true;
      }
      return false;
    } on ParseException catch (_) {
      return false;
    }
  }
}
