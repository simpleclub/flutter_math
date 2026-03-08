import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

import '../ast/options.dart';
import '../ast/style.dart';
import '../ast/syntax_tree.dart';
import '../parser/tex/parse_error.dart';
import '../parser/tex/parser.dart';
import '../parser/tex/settings.dart';
import '../utils/wrapper.dart';
import 'controller.dart';
import 'exception.dart';
import 'math.dart';
import 'mode.dart';
import 'selection/cursor_timer_manager.dart';
import 'selection/overlay_manager.dart';
import 'selection/selection_manager.dart';
import 'selection/web_selection_manager.dart';

const defaultSelection = TextSelection.collapsed(offset: -1);

/// Configures which context-menu actions are enabled for [SelectableMath].
@immutable
class SelectableMathToolbarOptions {
  /// Creates toolbar options for [SelectableMath].
  const SelectableMathToolbarOptions({
    this.copy = true,
    this.cut = false,
    this.paste = false,
    this.selectAll = true,
  });

  /// Whether the copy action should be available.
  final bool copy;

  /// Whether the cut action should be available.
  ///
  /// This is currently ignored because [SelectableMath] is read-only.
  final bool cut;

  /// Whether the paste action should be available.
  ///
  /// This is currently ignored because [SelectableMath] is read-only.
  final bool paste;

  /// Whether the select-all action should be available.
  final bool selectAll;

  /// Returns a copy of this configuration with the provided fields replaced.
  SelectableMathToolbarOptions copyWith({
    bool? copy,
    bool? cut,
    bool? paste,
    bool? selectAll,
  }) {
    return SelectableMathToolbarOptions(
      copy: copy ?? this.copy,
      cut: cut ?? this.cut,
      paste: paste ?? this.paste,
      selectAll: selectAll ?? this.selectAll,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SelectableMathToolbarOptions &&
        other.copy == copy &&
        other.cut == cut &&
        other.paste == paste &&
        other.selectAll == selectAll;
  }

  @override
  int get hashCode => Object.hash(copy, cut, paste, selectAll);
}

/// Selectable math widget.
///
/// On top of non-selectable [Math], it adds selection functionality. Users can
/// select by long press gesture, drag gesture, moving selection handles or
/// pointer selection. The selected region can be encoded into TeX and copied
/// to clipboard.
///
/// Use [SelectableMath] when users need to copy or inspect the TeX selection.
/// If you only need display, prefer [Math] for lower overhead.
///
/// See [SelectableText] as this widget aims to imitate its selection behavior.
class SelectableMath extends StatelessWidget {
  /// Creates selectable math from an already parsed [SyntaxTree].
  ///
  /// Provide either a built [ast] or a [parseException].
  ///
  /// Most applications should prefer [SelectableMath.tex], which parses a TeX
  /// string and returns a ready-to-use widget.
  const SelectableMath({
    Key? key,
    this.ast,
    this.autofocus = false,
    this.cursorColor,
    this.cursorRadius,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection = true,
    this.focusNode,
    this.mathStyle = MathStyle.display,
    this.logicalPpi,
    this.onErrorFallback = defaultOnErrorFallback,
    this.options,
    this.parseException,
    this.showCursor = false,
    this.textScaleFactor,
    this.textSelectionControls,
    this.textStyle,
    SelectableMathToolbarOptions? toolbarOptions,
  })  : assert(ast != null || parseException != null),
        toolbarOptions = toolbarOptions ?? const SelectableMathToolbarOptions(),
        super(key: key);

  /// The equation to display.
  ///
  /// It can be null only when [parseException] is not null.
  final SyntaxTree? ast;

  /// {@macro flutter.widgets.editableText.autofocus}
  final bool autofocus;

  /// The color to use when painting the cursor.
  ///
  /// Defaults to the theme's `cursorColor` when null.
  final Color? cursorColor;

  /// {@macro flutter.widgets.editableText.cursorRadius}
  final Radius? cursorRadius;

  /// {@macro flutter.widgets.editableText.cursorWidth}
  final double cursorWidth;

  /// {@macro flutter.widgets.editableText.cursorHeight}
  final double? cursorHeight;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// {@macro flutter.widgets.editableText.enableInteractiveSelection}
  final bool enableInteractiveSelection;

  /// Defines the focus for this widget.
  ///
  /// Math is only selectable when widget is focused.
  ///
  /// The [focusNode] is a long-lived object that's typically managed by a
  /// [StatefulWidget] parent. See [FocusNode] for more information.
  ///
  /// To give the focus to this widget, provide a [focusNode] and then
  /// use the current [FocusScope] to request the focus:
  ///
  /// ```dart
  /// FocusScope.of(context).requestFocus(myFocusNode);
  /// ```
  ///
  /// This happens automatically when the widget is tapped.
  ///
  /// To be notified when the widget gains or loses the focus, add a listener
  /// to the [focusNode]:
  ///
  /// ```dart
  /// focusNode.addListener(() { print(myFocusNode.hasFocus); });
  /// ```
  ///
  /// If null, this widget will create its own [FocusNode].
  final FocusNode? focusNode;

  /// {@macro flutter_math_fork.widgets.math.mathStyle}
  final MathStyle mathStyle;

  /// {@macro flutter_math_fork.widgets.math.logicalPpi}
  final double? logicalPpi;

  /// {@macro flutter_math_fork.widgets.math.onErrorFallback}
  final OnErrorFallback onErrorFallback;

  /// {@macro flutter_math_fork.widgets.math.options}
  final MathOptions? options;

  /// {@macro flutter_math_fork.widgets.math.parseError}
  final ParseException? parseException;

  /// {@macro flutter.widgets.editableText.showCursor}
  final bool showCursor;

  /// Multiplier applied to the effective text size before rendering.
  ///
  /// When null, the equation follows the ambient [MediaQuery] text scaling.
  final double? textScaleFactor;

  /// Optional delegate for building the text selection handles and toolbar.
  ///
  /// Works like [EditableText.selectionControls].
  final TextSelectionControls? textSelectionControls;

  /// {@macro flutter_math_fork.widgets.math.textStyle}
  final TextStyle? textStyle;

  /// Configuration of context menu options.
  ///
  /// Paste and cut are disabled regardless because this widget is read-only.
  ///
  /// If not set, copy and select-all are enabled by default.
  final SelectableMathToolbarOptions toolbarOptions;

  /// Creates selectable math from a TeX [expression].
  ///
  /// {@macro flutter_math_fork.widgets.math.tex_builder}
  ///
  /// See also:
  ///
  /// * [SelectableMath.mathStyle]
  /// * [SelectableMath.textStyle]
  factory SelectableMath.tex(
    String expression, {
    Key? key,
    TexParserSettings settings = const TexParserSettings(),
    MathOptions? options,
    OnErrorFallback onErrorFallback = defaultOnErrorFallback,
    bool autofocus = false,
    Color? cursorColor,
    Radius? cursorRadius,
    double cursorWidth = 2.0,
    double? cursorHeight,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    bool enableInteractiveSelection = true,
    FocusNode? focusNode,
    MathStyle mathStyle = MathStyle.display,
    double? logicalPpi,
    bool showCursor = false,
    double? textScaleFactor,
    TextSelectionControls? textSelectionControls,
    TextStyle? textStyle,
    SelectableMathToolbarOptions? toolbarOptions,
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
    return SelectableMath(
      key: key,
      ast: ast,
      autofocus: autofocus,
      cursorColor: cursorColor,
      cursorRadius: cursorRadius,
      cursorWidth: cursorWidth,
      cursorHeight: cursorHeight,
      dragStartBehavior: dragStartBehavior,
      enableInteractiveSelection: enableInteractiveSelection,
      focusNode: focusNode,
      mathStyle: mathStyle,
      logicalPpi: logicalPpi,
      onErrorFallback: onErrorFallback,
      options: options,
      parseException: parseError,
      showCursor: showCursor,
      textScaleFactor: textScaleFactor,
      textSelectionControls: textSelectionControls,
      textStyle: textStyle,
      toolbarOptions: toolbarOptions,
    );
  }

  Widget build(BuildContext context) {
    if (parseException != null) {
      return onErrorFallback(parseException!);
    }

    var effectiveTextStyle = textStyle;
    if (effectiveTextStyle == null || effectiveTextStyle.inherit) {
      effectiveTextStyle = DefaultTextStyle.of(context).style.merge(textStyle);
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

    final options = this.options ??
        MathOptions(
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

    // A trial build to catch any potential build errors
    try {
      ast!.buildWidget(options);
    } on BuildException catch (e) {
      return onErrorFallback(e);
    } on Object catch (e) {
      return onErrorFallback(
          BuildException('Unsanitized build exception detected: $e.'
              'Please report this error with corresponding input.'));
    }

    final theme = Theme.of(context);
    // The following code adapts for Flutter's new theme system (https://github.com/flutter/flutter/pull/62014/)
    final selectionTheme = TextSelectionTheme.of(context);

    var textSelectionControls = this.textSelectionControls;
    bool paintCursorAboveText;
    bool cursorOpacityAnimates;
    Offset? cursorOffset;
    var cursorColor = this.cursorColor;
    Color selectionColor;
    var cursorRadius = this.cursorRadius;
    bool forcePressEnabled;

    switch (theme.platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        forcePressEnabled = true;
        textSelectionControls ??= cupertinoTextSelectionControls;
        paintCursorAboveText = true;
        cursorOpacityAnimates = true;
        cursorColor ??= selectionTheme.cursorColor ??
            CupertinoTheme.of(context).primaryColor;
        selectionColor = selectionTheme.selectionColor ??
            CupertinoTheme.of(context).primaryColor;

        cursorRadius ??= const Radius.circular(2.0);
        cursorOffset = Offset(
            iOSHorizontalOffset / MediaQuery.of(context).devicePixelRatio, 0);
        break;

      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        forcePressEnabled = false;
        textSelectionControls ??= materialTextSelectionControls;
        paintCursorAboveText = false;
        cursorOpacityAnimates = false;
        cursorColor ??= selectionTheme.cursorColor ?? theme.colorScheme.primary;
        selectionColor =
            selectionTheme.selectionColor ?? theme.colorScheme.primary;

        break;
    }

    return RepaintBoundary(
      child: InternalSelectableMath(
        ast: ast!,
        autofocus: autofocus,
        cursorColor: cursorColor,
        cursorOffset: cursorOffset,
        cursorOpacityAnimates: cursorOpacityAnimates,
        cursorRadius: cursorRadius,
        cursorWidth: cursorWidth,
        cursorHeight: cursorHeight,
        dragStartBehavior: dragStartBehavior,
        enableInteractiveSelection: enableInteractiveSelection,
        focusNode: focusNode,
        forcePressEnabled: forcePressEnabled,
        options: options,
        paintCursorAboveText: paintCursorAboveText,
        selectionColor: selectionColor,
        showCursor: showCursor,
        textSelectionControls: textSelectionControls,
        toolbarOptions: toolbarOptions,
      ),
    );
  }

  /// Default fallback function for [Math], [SelectableMath]
  static Widget defaultOnErrorFallback(FlutterMathException error) =>
      Math.defaultOnErrorFallback(error);
}

/// The internal widget for [SelectableMath] when no errors are encountered.
class InternalSelectableMath extends StatefulWidget {
  const InternalSelectableMath({
    Key? key,
    required this.ast,
    this.autofocus = false,
    required this.cursorColor,
    this.cursorOffset,
    this.cursorOpacityAnimates = false,
    this.cursorRadius,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection = true,
    this.forcePressEnabled = false,
    this.focusNode,
    this.hintingColor,
    required this.options,
    this.paintCursorAboveText = false,
    this.selectionColor,
    this.showCursor = false,
    required this.textSelectionControls,
    required this.toolbarOptions,
  }) : super(key: key);

  final SyntaxTree ast;

  final bool autofocus;

  final Color cursorColor;

  final Offset? cursorOffset;

  final bool cursorOpacityAnimates;

  final Radius? cursorRadius;

  final double cursorWidth;

  final double? cursorHeight;

  final DragStartBehavior dragStartBehavior;

  final bool enableInteractiveSelection;

  final FocusNode? focusNode;

  final bool forcePressEnabled;

  final Color? hintingColor;

  final MathOptions options;

  final bool paintCursorAboveText;

  final Color? selectionColor;

  final bool showCursor;

  final TextSelectionControls textSelectionControls;

  final SelectableMathToolbarOptions toolbarOptions;

  @override
  InternalSelectableMathState createState() => InternalSelectableMathState();
}

class InternalSelectableMathState extends State<InternalSelectableMath>
    with
        AutomaticKeepAliveClientMixin,
        TextSelectionDelegate,
        SelectionManagerMixin,
        SelectionOverlayManagerMixin,
        WebSelectionControlsManagerMixin,
        SingleTickerProviderStateMixin,
        CursorTimerManagerMixin {
  static InternalSelectableMathState? _activeSelectableMath;

  TextSelectionControls get textSelectionControls =>
      widget.textSelectionControls;

  FocusNode? _focusNode;

  FocusNode get focusNode => widget.focusNode ?? (_focusNode ??= FocusNode());

  bool get showCursor => widget.showCursor; //?? false;

  bool get cursorOpacityAnimates => widget.cursorOpacityAnimates;

  DragStartBehavior get dragStartBehavior => widget.dragStartBehavior;

  late MathController controller;

  late FocusNode _oldFocusNode;

  @override
  void initState() {
    controller = MathController(ast: widget.ast);
    _oldFocusNode = focusNode..addListener(updateKeepAlive);
    super.initState();
  }

  @override
  void didUpdateWidget(InternalSelectableMath oldWidget) {
    if (widget.ast != controller.ast) {
      controller = MathController(ast: widget.ast);
    }
    if (_oldFocusNode != focusNode) {
      _oldFocusNode.removeListener(updateKeepAlive);
      _oldFocusNode = focusNode..addListener(updateKeepAlive);
    }
    super.didUpdateWidget(oldWidget);
  }

  bool _didAutoFocus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoFocus && widget.autofocus) {
      _didAutoFocus = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).autofocus(focusNode);
        }
      });
    }
  }

  @override
  void dispose() {
    _oldFocusNode.removeListener(updateKeepAlive);
    if (_activeSelectableMath == this) {
      _activeSelectableMath = null;
    }
    controller.dispose();
    super.dispose();
  }

  @override
  void requestFocusForInteraction() {
    final activeSelectableMath = _activeSelectableMath;
    if (activeSelectableMath != null &&
        activeSelectableMath != this &&
        activeSelectableMath.mounted) {
      activeSelectableMath.handleSelectionChanged(
        defaultSelection,
        null,
        ExtraSelectionChangedCause.unfocus,
      );
    }
    _activeSelectableMath = this;
    focusNode.requestFocus();
  }

  @override
  void handleSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause, [
    ExtraSelectionChangedCause? extraCause,
  ]) {
    if (extraCause == ExtraSelectionChangedCause.unfocus) {
      if (_activeSelectableMath == this) {
        _activeSelectableMath = null;
      }
    } else if (extraCause != ExtraSelectionChangedCause.exterior) {
      final activeSelectableMath = _activeSelectableMath;
      if (activeSelectableMath != null &&
          activeSelectableMath != this &&
          activeSelectableMath.mounted) {
        activeSelectableMath.handleSelectionChanged(
          defaultSelection,
          null,
          ExtraSelectionChangedCause.unfocus,
        );
      }
      _activeSelectableMath = this;
    }

    super.handleSelectionChanged(selection, cause, extraCause);
  }

  void onSelectionChanged(
      TextSelection selection, SelectionChangedCause? cause) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        if (cause == SelectionChangedCause.longPress) {
          bringIntoView(selection.base);
        }
        return;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      // Do nothing.
    }
  }

  Widget build(BuildContext context) {
    super.build(context); // See AutomaticKeepAliveClientMixin.

    final child = controller.ast.buildWidget(widget.options);

    return Focus.withExternalFocusNode(
      focusNode: focusNode,
      includeSemantics: false,
      child: TapRegion(
        groupId: toolbarLayerLink,
        onTapOutside: (_) {
          if (controller.selection == defaultSelection) {
            return;
          }
          handleSelectionChanged(
            defaultSelection,
            null,
            ExtraSelectionChangedCause.unfocus,
          );
        },
        child: selectionGestureDetectorBuilder.buildGestureDetector(
          behavior: HitTestBehavior.translucent,
          child: MouseRegion(
            cursor: SystemMouseCursors.text,
            child: CompositedTransformTarget(
              link: toolbarLayerLink,
              child: MultiProvider(
                providers: [
                  Provider.value(value: FlutterMathMode.select),
                  ChangeNotifierProvider.value(value: controller),
                  ProxyProvider<MathController, TextSelection>(
                    create: (context) =>
                        const TextSelection.collapsed(offset: -1),
                    update: (context, value, previous) => value.selection,
                  ),
                  Provider.value(
                    value: SelectionStyle(
                      cursorColor: widget.cursorColor,
                      cursorOffset: widget.cursorOffset,
                      cursorRadius: widget.cursorRadius,
                      cursorWidth: widget.cursorWidth,
                      cursorHeight: widget.cursorHeight,
                      selectionColor: widget.selectionColor,
                      paintCursorAboveText: widget.paintCursorAboveText,
                    ),
                  ),
                  Provider.value(
                    value: Tuple2(startHandleLayerLink, endHandleLayerLink),
                  ),
                  // We can't just provide an AnimationController, otherwise
                  // Provider will throw
                  Provider.value(value: Wrapper(cursorBlinkOpacityController)),
                ],
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => hasFocus;

  @override
  bool get copyEnabled => widget.toolbarOptions.copy;

  @override
  bool get cutEnabled => false;

  @override
  bool get pasteEnabled => false;

  @override
  bool get selectAllEnabled => widget.toolbarOptions.selectAll;

  @override
  bool get forcePressEnabled => widget.forcePressEnabled;

  @override
  bool get selectionEnabled => widget.enableInteractiveSelection;

  @override
  double get preferredLineHeight => widget.options.fontSize;

  @override
  List<ContextMenuButtonItem> get contextMenuButtonItems {
    return <ContextMenuButtonItem>[
      if (copyEnabled)
        ContextMenuButtonItem(
          type: ContextMenuButtonType.copy,
          onPressed: () => copySelection(SelectionChangedCause.toolbar),
        ),
      if (selectAllEnabled && !_selectionCoversAllContent)
        ContextMenuButtonItem(
          type: ContextMenuButtonType.selectAll,
          onPressed: () => selectAll(SelectionChangedCause.toolbar),
        ),
    ];
  }

  bool get _selectionCoversAllContent =>
      controller.selection.start == 0 &&
      controller.selection.end == controller.ast.greenRoot.capturedCursor - 1;

  @override
  void bringIntoView(TextPosition position) {
    final targetContext = controller.ast.greenRoot.key?.currentContext;
    if (targetContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      targetContext,
      duration: Duration.zero,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  @override
  void copySelection(SelectionChangedCause cause) {
    if (controller.selection.isCollapsed) {
      return;
    }

    final selectedText = textEditingValue.selection.textInside(
      textEditingValue.text,
    );
    if (selectedText.isEmpty) {
      return;
    }

    Clipboard.setData(ClipboardData(text: selectedText));

    if (cause != SelectionChangedCause.toolbar) {
      return;
    }

    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        controller.selection = defaultSelection;
        break;
      case TargetPlatform.iOS:
        hideToolbar(false);
        break;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        hideToolbar();
        break;
    }
  }

  @override
  void cutSelection(SelectionChangedCause cause) {}

  @override
  Future<void> pasteText(SelectionChangedCause cause) async {}

  @override
  void selectAll(SelectionChangedCause cause) {
    final fullSelection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.ast.greenRoot.capturedCursor - 1,
    );
    handleSelectionChanged(
      fullSelection,
      cause,
      cause == SelectionChangedCause.toolbar
          ? ExtraSelectionChangedCause.handle
          : null,
    );
    if (cause == SelectionChangedCause.toolbar) {
      bringIntoView(fullSelection.extent);
    }
  }

  @override
  void userUpdateTextEditingValue(
    TextEditingValue value,
    SelectionChangedCause cause,
  ) {
    textEditingValue = value;
  }
}

class SelectionStyle {
  final Color cursorColor;
  final Offset? cursorOffset;
  final Radius? cursorRadius;
  final double cursorWidth;
  final double? cursorHeight;
  final Color? hintingColor;
  final bool paintCursorAboveText;
  final Color? selectionColor;
  final bool showCursor;

  const SelectionStyle({
    required this.cursorColor,
    this.cursorOffset,
    this.cursorRadius,
    this.cursorWidth = 1.0,
    this.cursorHeight,
    this.hintingColor,
    this.paintCursorAboveText = false,
    this.selectionColor,
    this.showCursor = false,
  });

  @override
  bool operator ==(Object o) {
    if (identical(this, o)) return true;

    return o is SelectionStyle &&
        o.cursorColor == cursorColor &&
        o.cursorOffset == cursorOffset &&
        o.cursorRadius == cursorRadius &&
        o.cursorWidth == cursorWidth &&
        o.cursorHeight == cursorHeight &&
        o.hintingColor == hintingColor &&
        o.paintCursorAboveText == paintCursorAboveText &&
        o.selectionColor == selectionColor &&
        o.showCursor == showCursor;
  }

  @override
  int get hashCode => Object.hash(
        cursorColor,
        cursorOffset,
        cursorRadius,
        cursorWidth,
        cursorHeight,
        hintingColor,
        paintCursorAboveText,
        selectionColor,
        showCursor,
      );
}
