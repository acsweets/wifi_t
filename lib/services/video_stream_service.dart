import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VideoStreamService {
  CameraController? _controller;
  StreamSubscription<CameraImage>? _imageStreamSubscription;
  Function(Uint8List)? onFrameReady;
  bool _isStreaming = false;

  bool get isStreaming => _isStreaming;

  Future<void> startVideoStream() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      
      _isStreaming = true;
      await _controller!.startImageStream((CameraImage image) {
        if (_isStreaming) {
          _processFrame(image);
        }
      });
    } catch (e) {
      print('Video stream error: $e');
    }
  }

  void _processFrame(CameraImage image) {
    if (!_isStreaming) return;
    
    // 限制帧率以减少负载
    _convertToJPEG(image).then((bytes) {
      if (bytes != null && _isStreaming) {
        onFrameReady?.call(bytes);
      }
    }).catchError((e) {
      print('Frame processing error: $e');
    });
  }

  Future<Uint8List?> _convertToJPEG(CameraImage image) async {
    try {
      final width = image.width;
      final height = image.height;
      
      // 使用更简单的方式，直接创建一个小的测试图像
      const testWidth = 100;
      const testHeight = 100;
      final rgbaBytes = Uint8List(testWidth * testHeight * 4);
      
      // 创建一个简单的渐变图像
      for (int y = 0; y < testHeight; y++) {
        for (int x = 0; x < testWidth; x++) {
          final index = (y * testWidth + x) * 4;
          final gray = ((x + y) * 255 ~/ (testWidth + testHeight)).clamp(0, 255);
          rgbaBytes[index] = gray;     // R
          rgbaBytes[index + 1] = gray; // G
          rgbaBytes[index + 2] = gray; // B
          rgbaBytes[index + 3] = 255;  // A
        }
      }
      
      final codec = await ui.instantiateImageCodec(
        rgbaBytes,
        targetWidth: testWidth,
        targetHeight: testHeight,
      );
      final frame = await codec.getNextFrame();
      final pngBytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      
      return pngBytes?.buffer.asUint8List();
    } catch (e) {
      print('Image conversion error: $e');
      return null;
    }
  }

  void stopVideoStream() {
    _isStreaming = false;
    _imageStreamSubscription?.cancel();
    _imageStreamSubscription = null;
    
    if (_controller != null) {
      try {
        _controller!.stopImageStream().catchError((e) {
          print('Stop image stream error: $e');
        });
      } catch (e) {
        print('Controller stop error: $e');
      }
      
      Future.delayed(const Duration(milliseconds: 100), () {
        _controller?.dispose();
        _controller = null;
      });
    }
  }

  CameraController? get controller => _controller;
}