import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CustomCamera extends StatefulWidget {
  final Function(List<File>) onImagesCaptured;
  final int maxImages;
  final int currentImageCount;

  const CustomCamera({
    Key? key,
    required this.onImagesCaptured,
    this.maxImages = 6,
    this.currentImageCount = 0,
  }) : super(key: key);

  @override
  State<CustomCamera> createState() => _CustomCameraState();
}

class _CustomCameraState extends State<CustomCamera> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isInitialized = false;
  bool _isTakingPicture = false;
  bool _isProcessingImages = false;
  List<File> _capturedImages = [];
  late int _maxImages;
  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _maxImages = widget.maxImages;
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Camera initialization timeout');
        },
      );

      if (cameras != null && cameras!.isNotEmpty) {
        await _switchToCamera(_currentCameraIndex);
      } else {
        throw Exception('No cameras available');
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ไม่สามารถเข้าถึงกล้องได้'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _switchToCamera(int cameraIndex) async {
    if (cameras == null || cameraIndex >= cameras!.length) return;

    setState(() {
      _isInitialized = false;
    });

    try {
      // Dispose current controller
      await _controller?.dispose();

      _controller = CameraController(
        cameras![cameraIndex],
        ResolutionPreset.max,
        enableAudio: false,
      );

      await _controller!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Camera initialization timeout');
        },
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _currentCameraIndex = cameraIndex;
        });
      }
    } catch (e) {
      debugPrint('Error switching camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ไม่สามารถเปลี่ยนกล้องได้'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        // Try to reinitialize with original camera
        if (_currentCameraIndex != cameraIndex) {
          await _switchToCamera(_currentCameraIndex);
        }
      }
    }
  }

  void _switchCamera() {
    if (cameras == null || cameras!.length <= 1) return;

    final nextCameraIndex = (_currentCameraIndex + 1) % cameras!.length;
    _switchToCamera(nextCameraIndex);
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    if ((_capturedImages.length + widget.currentImageCount) >= _maxImages) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ถ่ายรูปได้สูงสุด $_maxImages รูปแล้ว'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      _isTakingPicture = true;
    });

    try {
      final XFile picture = await _controller!.takePicture().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Camera timeout');
        },
      );

      final File imageFile = File(picture.path);

      if (mounted) {
        setState(() {
          _capturedImages.add(imageFile);
          _isTakingPicture = false;
        });
      }

    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });

        if (!e.toString().contains('timeout')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('เกิดข้อผิดพลาดในการถ่ายรูป'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void _finishCapturing() {
    if (_capturedImages.isNotEmpty && !_isProcessingImages) {
      setState(() {
        _isProcessingImages = true;
      });

      widget.onImagesCaptured(_capturedImages);
      Navigator.of(context).pop();
    }
  }

  void _removeImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final cameraAspectRatio = _controller!.value.aspectRatio;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Container(
              width: screenSize.width * 1.0,
              height: screenSize.height * 0.65,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // Top controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    if (cameras != null && cameras!.length > 1)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: _switchCamera,
                          icon: const Icon(
                            Icons.flip_camera_ios,
                            color: Colors.white,
                            size: 24,
                          ),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${_capturedImages.length + widget.currentImageCount}/${_maxImages}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    if (_capturedImages.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: _isProcessingImages
                              ? Colors.grey.withOpacity(0.8)
                              : Colors.green.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: _isProcessingImages ? null : _finishCapturing,
                          icon: _isProcessingImages
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 24,
                                ),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (_capturedImages.isNotEmpty)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _capturedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _capturedImages[index],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -5,
                            right: -5,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: SafeArea(
                child: GestureDetector(
                  onTap: (_isTakingPicture || _isProcessingImages) ? null : _takePicture,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: (_capturedImages.length + widget.currentImageCount) >= _maxImages
                            ? Colors.grey
                            : Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _isTakingPicture
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Icon(
                            Icons.camera_alt,
                            color: (_capturedImages.length + widget.currentImageCount) >= _maxImages
                                ? Colors.grey
                                : Colors.black,
                            size: 40,
                          ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 140,
            height: 180,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  _capturedImages.isEmpty
                      ? 'แตะเพื่อถ่ายรูป'
                      : 'ถ่ายรูปต่อหรือแตะ ✓ เพื่อเสร็จสิ้น',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> openMultiImageCamera(
  BuildContext context,
  Function(List<File>) onImagesCaptured, {
  int maxImages = 6,
  int currentImageCount = 0,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => CustomCamera(
        onImagesCaptured: onImagesCaptured,
        maxImages: maxImages,
        currentImageCount: currentImageCount,
      ),
    ),
  );
}
