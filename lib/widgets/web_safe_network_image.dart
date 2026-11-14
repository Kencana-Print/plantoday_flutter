import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Di web, elemen <img> HTML native tidak terkena blokir CORS CanvasKit.
// Untuk mobile/desktop, gunakan Image.network biasa.
import 'web_image_stub.dart'
    if (dart.library.js_interop) 'web_image_web.dart' as platform_image;

class WebSafeNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const WebSafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  @override
  State<WebSafeNetworkImage> createState() => _WebSafeNetworkImageState();
}

class _WebSafeNetworkImageState extends State<WebSafeNetworkImage> {
  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.trim().isEmpty) {
      return _buildError(context);
    }

    if (kIsWeb) {
      return platform_image.buildPlatformWebImage(
        imageUrl: widget.imageUrl,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: widget.errorBuilder ?? (ctx, err, stack) => _buildError(context),
      );
    }

    return Image.network(
      widget.imageUrl,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: widget.errorBuilder ??
          (ctx, err, stack) => _buildError(context),
    );
  }

  Widget _buildError(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const Text(
        'Tidak ada foto',
        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
      ),
    );
  }
}
