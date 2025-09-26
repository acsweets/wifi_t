import 'dart:typed_data';
import 'dart:ui' as ui;

class VideoFrameGenerator {
  static Future<Uint8List> generateTestFrame(int frameNumber) async {
    const width = 100;
    const height = 100;
    
    // 创建RGBA像素数据
    final pixels = Uint8List(width * height * 4);
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final index = (y * width + x) * 4;
        
        // 创建动态渐变效果
        final r = ((x + frameNumber) % 256);
        final g = ((y + frameNumber) % 256);
        final b = ((x + y + frameNumber) % 256);
        
        pixels[index] = r;     // R
        pixels[index + 1] = g; // G
        pixels[index + 2] = b; // B
        pixels[index + 3] = 255; // A
      }
    }
    
    // 转换为PNG
    final codec = await ui.instantiateImageCodec(
      pixels,
      targetWidth: width,
      targetHeight: height,
    );
    final frame = await codec.getNextFrame();
    final pngData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    
    return pngData!.buffer.asUint8List();
  }
}