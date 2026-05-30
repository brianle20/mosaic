import 'package:flutter/material.dart';

class KeyboardDismissRegion extends StatelessWidget {
  const KeyboardDismissRegion({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _dismissKeyboardIfOutsideFocusedField,
      child: child,
    );
  }

  void _dismissKeyboardIfOutsideFocusedField(PointerDownEvent event) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) {
      return;
    }

    if (_containsGlobalPosition(focus.context, event.position)) {
      return;
    }

    focus.unfocus();
  }

  bool _containsGlobalPosition(BuildContext? context, Offset globalPosition) {
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final bounds = topLeft & renderObject.size;
    return bounds.contains(globalPosition);
  }
}
