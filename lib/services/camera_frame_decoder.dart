import 'dart:typed_data';
import 'dart:ui' as ui;

class CameraFrameDecoder {
  static Future<Uint8List?> decodeYUVToImage(Uint8List yuvData, int width, int height) async {
    try {
      // 假设数据是压缩的Y通道数据
      final targetWidth = 160;
      final targetHeight = 120;
      final rgbaBytes = Uint8List(targetWidth * targetHeight * 4);
      
      // 将Y数据转换为灰度RGBA图像
      for (int i = 0; i < yuvData.length && i < targetWidth * targetHeight; i++) {
        final gray = yuvData[i];
        final rgbaIndex = i * 4;
        
        if (rgbaIndex + 3 < rgbaBytes.length) {
          rgbaBytes[rgbaIndex] = gray;     // R
          rgbaBytes[rgbaIndex + 1] = gray; // G
          rgbaBytes[rgbaIndex + 2] = gray; // B
          rgbaBytes[rgbaIndex + 3] = 255;  // A
        }
      }
      
      // 转换为PNG
      final codec = await ui.instantiateImageCodec(
        rgbaBytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      final pngBytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      
      return pngBytes?.buffer.asUint8List();
    } catch (e) {
      print('Decode error: $e');
      return null;
    }
  }
}