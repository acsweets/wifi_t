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
      // 简化处理：只取Y通道数据并压缩
      final yPlane = image.planes[0];
      final yBytes = yPlane.bytes;
      
      // 取样压缩：每4个像素取1个
      final compressedSize = (yBytes.length / 16).round();
      final compressedData = Uint8List(compressedSize);
      
      for (int i = 0; i < compressedSize; i++) {
        final sourceIndex = i * 16;
        if (sourceIndex < yBytes.length) {
          compressedData[i] = yBytes[sourceIndex];
        }
      }
      
      return compressedData;
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