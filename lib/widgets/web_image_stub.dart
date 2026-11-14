import 'package:flutter/material.dart';

Widget buildPlatformWebImage({
  required String imageUrl,
  required BoxFit fit,
  double? width,
  double? height,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
}) {
  return Image.network(
    imageUrl,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: errorBuilder,
  );
}
