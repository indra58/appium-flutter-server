import 'package:appium_flutter_server/src/internal/flutter_element.dart';
import 'package:appium_flutter_server/src/utils/element_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ElementSerializer {
  static Future<Map<String, dynamic>> serialize(
    Element element, {
    Set<Element>? visited,
    int depth = 0,
  }) async {
    visited ??= <Element>{};
    if (visited.contains(element)) {
      return {};
    }
    visited.add(element);

    final widget = element.widget;
    final renderObject = element.renderObject;
    Rect? rect;
    if (renderObject is RenderBox && renderObject.hasSize && renderObject.attached) {
      try {
        final origin = renderObject.localToGlobal(Offset.zero);
        final size = renderObject.size;
        final dpr = WidgetsBinding.instance.platformDispatcher.views.firstOrNull?.devicePixelRatio ?? 1.0;
        rect = Rect.fromLTWH(
          origin.dx * dpr,
          origin.dy * dpr,
          size.width * dpr,
          size.height * dpr,
        );
      } catch (_) {
        rect = renderObject.paintBounds;
      }
    } else {
      rect = renderObject?.paintBounds;
    }

    final children =
        await _serializeChildren(element, visited: visited, depth: depth);

    final attributes = await _serializeAttributes(widget);
    final visualProperties = await _serializeVisualProperties(widget);
    final stateProperties = _serializeStateProperties(widget);

    String? keyString;
    if (widget.key != null) {
      keyString = widget.key.toString();
    } else {
      try {
        final dynamic dw = widget;
        final dynamic customId =
            dw.keyId ??
            dw.identifier ??
            dw.id ??
            dw.testId ??
            dw.automationId ??
            dw.testKey ??
            dw.keyName;
        if (customId != null) {
          keyString = customId.toString();
        }
      } catch (_) {}
    }

    return {
      'type': widget.runtimeType.toString(),
      'elementType': element.runtimeType.toString(),
      'description': widget.toStringShort(),
      'depth': depth,
      if (keyString != null) 'key': keyString,
      'attributes': attributes,
      'visual': visualProperties,
      'state': stateProperties,
      if (rect != null)
        'rect': {
          'x': rect.left,
          'y': rect.top,
          'width': rect.width,
          'height': rect.height,
        },
      'children': children,
    };
  }

  static Future<List<Map<String, dynamic>>> _serializeChildren(
    Element element, {
    required Set<Element> visited,
    required int depth,
  }) async {
    final List<Map<String, dynamic>> children = [];
    final List<Future<Map<String, dynamic>>> childrenFutures = [];
    element.visitChildren((child) {
      childrenFutures.add(serialize(child, visited: visited, depth: depth + 1));
    });
    final resolvedChildren = await Future.wait(childrenFutures);
    for (final childJson in resolvedChildren) {
      if (childJson.isNotEmpty) {
        children.add(childJson);
      }
    }
    return children;
  }

  static Future<Map<String, String?>> _serializeAttributes(
      Widget widget) async {
    String? text;
    try {
      final flutterElement = FlutterElement.fromBy(find.byWidget(widget));
      text = await ElementHelper.getText(flutterElement);
    } catch (_) {
      text = null;
    }

    String? semanticsLabel;
    String? tooltip;
    String? hintText;

    if (widget is Semantics) {
      semanticsLabel = widget.properties.label;
    } else if (widget is Tooltip) {
      tooltip = widget.message;
    } else if (widget is IconButton) {
      tooltip = widget.tooltip;
    } else if (widget is Icon) {
      semanticsLabel = widget.semanticLabel;
    } else if (widget is Image) {
      semanticsLabel = widget.semanticLabel;
    } else if (widget is TextField) {
      hintText = widget.decoration?.hintText;
    }

    return {
      if (text?.isNotEmpty ?? false) 'text': text,
      if (semanticsLabel != null) 'semanticsLabel': semanticsLabel,
      if (tooltip != null) 'tooltip': tooltip,
      if (hintText != null) 'hintText': hintText,
    };
  }

  static Future<Map<String, dynamic>> _serializeVisualProperties(
      Widget widget) async {
    double? fontSize;
    String? fontWeight;
    String? fontStyle;
    String? backgroundColor;
    String? color;

    if (widget is Text) {
      final style = widget.style;
      fontSize = style?.fontSize;
      fontWeight = style?.fontWeight?.toString();
      fontStyle = style?.fontStyle?.toString();
      color = style?.color?.toString();
    } else if (widget is Container) {
      if (widget.decoration is BoxDecoration) {
        backgroundColor =
            (widget.decoration as BoxDecoration).color?.toString();
      }
    } else if (widget is ElevatedButton) {
      final backgroundColorProperty = widget.style?.backgroundColor;
      final resolvedColor = backgroundColorProperty?.resolve(<WidgetState>{});
      if (resolvedColor != null) {
        backgroundColor = resolvedColor.toString();
      }
    }

    return {
      if (fontSize != null) 'fontSize': fontSize,
      if (fontWeight != null) 'fontWeight': fontWeight,
      if (fontStyle != null) 'fontStyle': fontStyle,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
      if (color != null) 'color': color,
    };
  }

  static Map<String, dynamic> _serializeStateProperties(Widget widget) {
    bool? enabled;
    bool? focused;
    bool? visible;
    bool? checked;
    bool? password;

    if (widget is EditableText) {
      focused = widget.focusNode.hasFocus;
      password = widget.obscureText;
    } else if (widget is TextField) {
      enabled = widget.enabled ?? true;
      focused = widget.focusNode?.hasFocus ?? false;
      password = widget.obscureText;
    } else if (widget is Switch) {
      checked = widget.value;
      enabled = widget.onChanged != null;
    } else if (widget is Checkbox) {
      checked = widget.value ?? false;
      enabled = widget.onChanged != null;
    } else if (widget is Radio) {
      checked = widget.value == widget.groupValue;
      enabled = widget.onChanged != null;
    } else if (widget is ButtonStyleButton) {
      enabled = widget.enabled;
    } else if (widget is Visibility) {
      visible = widget.visible;
    } else if (widget is Offstage) {
      visible = !widget.offstage;
    }

    return {
      if (enabled != null) 'enabled': enabled,
      if (focused != null) 'focused': focused,
      if (visible != null) 'visible': visible,
      if (checked != null) 'checked': checked,
      if (password != null) 'password': password,
    };
  }
}
