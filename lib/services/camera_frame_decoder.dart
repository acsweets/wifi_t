import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

// class CameraFrameDecoder {
//   static Future<Uint8List?> decodeYUVToImage(Uint8List yuvData, int width, int height) async {
//     try {
//       // 假设数据是压缩的Y通道数据
//       final targetWidth = 160;
//       final targetHeight = 120;
//       final rgbaBytes = Uint8List(targetWidth * targetHeight * 4);
//
//       // 将Y数据转换为灰度RGBA图像
//       for (int i = 0; i < yuvData.length && i < targetWidth * targetHeight; i++) {
//         final gray = yuvData[i];
//         final rgbaIndex = i * 4;
//
//         if (rgbaIndex + 3 < rgbaBytes.length) {
//           rgbaBytes[rgbaIndex] = gray;     // R
//           rgbaBytes[rgbaIndex + 1] = gray; // G
//           rgbaBytes[rgbaIndex + 2] = gray; // B
//           rgbaBytes[rgbaIndex + 3] = 255;  // A
//         }
//       }
//
//       // 转换为PNG
//       final codec = await ui.instantiateImageCodec(
//         rgbaBytes,
//         targetWidth: targetWidth,
//         targetHeight: targetHeight,
//       );
//       final frame = await codec.getNextFrame();
//       final pngBytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
//
//       return pngBytes?.buffer.asUint8List();
//     } catch (e) {
//       print('Decode error: $e');
//       return null;
//     }
//   }
// }

import 'dart:typed_data';
import 'dart:ui' as ui;

class CameraFrameDecoder {
  static Future<Uint8List?> decodeYUVToImage(Uint8List yData, int width, int height) async {
    try {
      final rgbaBytes = Uint8List(width * height * 4);

      for (int i = 0; i < yData.length && i < width * height; i++) {
        final gray = yData[i];
        final index = i * 4;
        rgbaBytes[index] = gray;
        rgbaBytes[index + 1] = gray;
        rgbaBytes[index + 2] = gray;
        rgbaBytes[index + 3] = 255;
      }

      final completer = Completer<Uint8List>();
      ui.decodeImageFromPixels(
        rgbaBytes,
        width,
        height,
        ui.PixelFormat.rgba8888,
            (ui.Image img) async {
          final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
          completer.complete(byteData?.buffer.asUint8List());
        },
      );

      return completer.future;
    } catch (e) {
      print('Decode error: $e');
      return null;
    }
  }
}
