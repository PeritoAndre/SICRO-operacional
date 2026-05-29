import 'package:flutter/widgets.dart';

Rect sharePositionOriginFor(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  final topLeft = renderObject.localToGlobal(Offset.zero);
  return topLeft & renderObject.size;
}
