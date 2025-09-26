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
      final yPlane = image.planes[0];
      final width = image.width;
      final height = image.height;
      
      // 取更大的数据块，但仍然要压缩
      const targetWidth = 80;
      const targetHeight = 60;
      final targetData = Uint8List(targetWidth * targetHeight);
      
      for (int y = 0; y < targetHeight; y++) {
        for (int x = 0; x < targetWidth; x++) {
          final srcX = (x * width / targetWidth).floor();
          final srcY = (y * height / targetHeight).floor();
          final srcIndex = srcY * yPlane.bytesPerRow + srcX;
          
          if (srcIndex < yPlane.bytes.length) {
            targetData[y * targetWidth + x] = yPlane.bytes[srcIndex];
          }
        }
      }
      
      return targetData;
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