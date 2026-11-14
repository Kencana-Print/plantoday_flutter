import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final Set<String> _registeredViewTypes = {};

Widget buildPlatformWebImage({
  required String imageUrl,
  required BoxFit fit,
  double? width,
  double? height,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
}) {
  final objectFit = switch (fit) {
    BoxFit.contain => 'contain',
    BoxFit.cover => 'cover',
    BoxFit.fill => 'fill',
    BoxFit.fitWidth => 'scale-down',
    BoxFit.fitHeight => 'scale-down',
    _ => 'cover',
  };

  // Gunakan hash string URL + objectFit sebagai unique viewType agar mode contain & cover terpisah
  final viewType = 'img-${imageUrl.hashCode}-$objectFit';

  if (!_registeredViewTypes.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final img = web.HTMLImageElement()
        ..src = imageUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = objectFit
        ..style.borderRadius = '10px'
        ..style.border = 'none';
      return img;
    });
    _registeredViewTypes.add(viewType);
  }

  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewType),
  );
}
