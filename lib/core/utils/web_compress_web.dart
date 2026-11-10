import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<Uint8List> compressImageForWeb(
  Uint8List inputBytes, {
  required int maxWidth,
  required int maxHeight,
  required double quality,
}) async {
  try {
    final blob = web.Blob(
      [inputBytes.toJS].toJS,
      web.BlobPropertyBag(type: 'image/jpeg'),
    );
    final blobUrl = web.URL.createObjectURL(blob);

    final img = web.HTMLImageElement();
    final completer = Completer<Uint8List>();

    img.onLoad.listen((_) {
      try {
        int width = img.naturalWidth;
        int height = img.naturalHeight;

        if (width <= 0 || height <= 0) {
          web.URL.revokeObjectURL(blobUrl);
          completer.complete(inputBytes);
          return;
        }

        if (width > maxWidth || height > maxHeight) {
          final aspect = width / height;
          if (width > height) {
            width = maxWidth;
            height = (maxWidth / aspect).round();
          } else {
            height = maxHeight;
            width = (maxHeight * aspect).round();
          }
        }

        final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
        canvas.width = width;
        canvas.height = height;

        final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
        ctx.drawImage(img, 0, 0, width.toDouble(), height.toDouble());

        canvas.toBlob(
          (web.Blob? compressedBlob) {
            web.URL.revokeObjectURL(blobUrl);
            if (compressedBlob == null) {
              completer.complete(inputBytes);
              return;
            }
            final reader = web.FileReader();
            reader.onLoadEnd.listen((_) {
              final result = reader.result;
              if (result != null && result.isA<JSArrayBuffer>()) {
                final buffer = (result as JSArrayBuffer).toDart;
                completer.complete(buffer.asUint8List());
              } else {
                completer.complete(inputBytes);
              }
            });
            reader.readAsArrayBuffer(compressedBlob);
          }.toJS,
          'image/jpeg',
          quality.toJS,
        );
      } catch (_) {
        web.URL.revokeObjectURL(blobUrl);
        completer.complete(inputBytes);
      }
    });

    img.onError.listen((_) {
      web.URL.revokeObjectURL(blobUrl);
      completer.complete(inputBytes);
    });

    img.src = blobUrl;
    return await completer.future;
  } catch (_) {
    return inputBytes;
  }
}
