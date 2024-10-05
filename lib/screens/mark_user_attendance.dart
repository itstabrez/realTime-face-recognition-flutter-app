import 'dart:io';
import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:realtime_face_recognition/ML/Recognition.dart';
import 'package:realtime_face_recognition/ML/Recognizer.dart';
import 'package:realtime_face_recognition/geofencing.dart';

class MarkUserAttendance extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MarkUserAttendance({
    Key? key,
    required this.cameras,
  }) : super(key: key);

  @override
  State<MarkUserAttendance> createState() => _MarkUserAttendanceState();
}

class _MarkUserAttendanceState extends State<MarkUserAttendance>
    with SingleTickerProviderStateMixin {
  dynamic controller;
  bool isBusy = false;
  late Size size;
  late CameraDescription description;
  CameraLensDirection camDirec = CameraLensDirection.front;
  late List<Recognition> recognitions = [];
  bool isStreamingFrame = false;
  bool isDetecting = true;
  late AnimationController _animationController;
  bool isInGeoFence = false;
  bool isLoading = true;

  //TODO declare face detector
  late FaceDetector faceDetector;

  //TODO declare face recognizer
  late Recognizer recognizer;

  // Instantiate the GeofencingService
  late GeofencingService geofencingService;

  @override
  void initState() {
    super.initState();
    initializeResources();
  }

  Future<void> initializeResources() async {
    description = widget.cameras.isNotEmpty
        ? widget.cameras[1]
        : throw Exception('No cameras available');
    //TODO initialize face detector
    var options =
        FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate);
    faceDetector = FaceDetector(options: options);
    //TODO initialize face recognizer
    recognizer = Recognizer();

    bool isConnected = await _isConnectedToNetwork();

    // Initialize the GeofencingService with context and geofence details
    // MY CURRENT LOCATION
    // geofencingService = GeofencingService(
    //   context: context,
    //   targetLatitude: 24.951708, // Example latitude
    //   targetLongitude: 86.186671, // Example longitude
    //   radiusInMeters: 100.0, // Example radius
    // );
    //YASIR CURRENT LOCATION
    geofencingService = GeofencingService(
      context: context,
      targetLatitude: 25.605028, // Example latitude
      targetLongitude: 85.078028, // Example longitude
      radiusInMeters: 300.0, // Example radius
    );

    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true); // Repeats the animation back and forth
    // Initialize camera footage
    setState(() {
      isLoading = true;
    });

    if (!isConnected) {
      // Show a dialog if the device is offline
      Navigator.pop(context);
      _showNoNetworkDialog();
    } else {
      isInGeoFence = await geofencingService.checkDeviceInRange();
      if (isInGeoFence) {
        setState(() {
          isLoading = false;
        });
        await initializeCamera();
      } else if (!isInGeoFence) {
        setState(() {
          isLoading = false;
        });
        _showOutOfRangeDialog();
      }
    }
  }

  // Check if the device is connected to the internet
  Future<bool> _isConnectedToNetwork() async {
    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());

    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.ethernet)) {
      return true;
    } else {
      return false;
    }
  }

  List<List<Recognition>> frameBuffer = [];
  int maxBufferSize = 3; // Number of frames to buffer

//TODO code to initialize the camera feed
  initializeCamera() async {
    controller = CameraController(description, ResolutionPreset.medium,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21 // for Android
            : ImageFormatGroup.bgra8888,
        enableAudio: true); // for iOS
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }

      controller.startImageStream((image) {
        if (!isBusy) {
          isStreamingFrame = true;
          isBusy = true;
          frame = image;
          doFaceDetectionOnFrame();
        }
      });
    });
  }

  // Show a dialog when the network is not available
  void _showNoNetworkDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('No Network Connection'),
          content: const Text('Please connect to a network to continue.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  // Show dialog if the device is out of range
  void _showOutOfRangeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Out of Range'),
          content: const Text('You are outside the allowed geofenced area.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  //TODO face detection on a frame
  dynamic _scanResults;
  CameraImage? frame;
  doFaceDetectionOnFrame() async {
    //TODO convert frame into InputImage format
    print('dfd');
    InputImage? inputImage = getInputImage();
    if (inputImage != null) {
      //TODO pass InputImage to face detection model and detect faces

      List<Face> faces = await faceDetector.processImage(inputImage);
      print("fl=" + faces.length.toString());

      //TODO perform face recognition on detected faces
      await performFaceRecognition(faces);
    }
  }

  img.Image? image;
  bool register = false;
// TODO: Perform Face Recognition with buffering
  performFaceRecognition(List<Face> faces) async {
    recognitions.clear();

    // TODO: Convert CameraImage to Image and rotate it
    image = Platform.isIOS
        ? _convertBGRA8888ToImage(frame!) as img.Image?
        : _convertNV21(frame!);
    image = Platform.isIOS
        ? img.copyRotate(image!,
            angle: camDirec == CameraLensDirection.front ? 360 : 90)
        : img.copyRotate(image!,
            angle: camDirec == CameraLensDirection.front ? 270 : 90);

    List<Recognition> currentFrameRecognitions = [];

    for (Face face in faces) {
      Rect faceRect = face.boundingBox;

      // TODO: Crop face
      img.Image croppedFace = img.copyCrop(image!,
          x: faceRect.left.toInt(),
          y: faceRect.top.toInt(),
          width: faceRect.width.toInt(),
          height: faceRect.height.toInt());

      // TODO: Pass cropped face to face recognition model
      Recognition recognition = recognizer.recognize(croppedFace, faceRect);
      if (recognition.distance > 0.75 || recognition.distance < 0.00) {
        recognition.name = "Unknown";
      }
      currentFrameRecognitions.add(recognition);
      // Add current frame recognitions to the buffer
      frameBuffer.add(currentFrameRecognitions);

      // If buffer reaches the required size then
      if (frameBuffer.length >= maxBufferSize) {
        // Get the latest frame recognitions
        List<Recognition> latestFrameRecognitions = frameBuffer.last;

        // Check if any face is recognized
        bool isVerified = false;
        for (Recognition recognition in latestFrameRecognitions) {
          if (recognition.distance <= 0.75 && recognition.distance >= 0.00) {
            isVerified = true;
            break;
          }
        }

        // Show appropriate dialog based on recognition
        if (isVerified) {
          showAttendanceMarkedDialog(latestFrameRecognitions.first.name);
        } else {
          showFaceNotVerifiedDialog();
        }

        // Clear the buffer for the next round of frames
        frameBuffer.clear();
      }
    }

    if (mounted) {
      setState(() {
        isBusy = false;
        _scanResults = currentFrameRecognitions;
      });
    }
  }

  // Show attendance marked dialog
  Future<void> showAttendanceMarkedDialog(String name) async {
    await controller.stopImageStream();
    isStreamingFrame = false;
    return showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissal of dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Attendance Marked',
            style: TextStyle(color: Colors.green),
          ),
          content: Text('$name Your attendance has been successfully marked.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> showFaceNotVerifiedDialog() async {
    await controller.stopImageStream();
    isStreamingFrame = false;
    return showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissal of dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Unknown Face Detected',
            style: TextStyle(color: Colors.red),
          ),
          content: const Text(
            'Please register your face first to mark attendance.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  static var IOS_BYTES_OFFSET = 28;

  static img.Image _convertBGRA8888ToImage(CameraImage cameraImage) {
    final plane = cameraImage.planes[0];

    return img.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: plane.bytes.buffer,
      rowStride: plane.bytesPerRow,
      bytesOffset: IOS_BYTES_OFFSET,
      order: img.ChannelOrder.bgra,
    );
  }

  static img.Image _convertNV21(CameraImage image) {
    final width = image.width.toInt();
    final height = image.height.toInt();

    Uint8List yuv420sp = image.planes[0].bytes;

    final outImg = img.Image(height: height, width: width);
    final int frameSize = width * height;

    for (int j = 0, yp = 0; j < height; j++) {
      int uvp = frameSize + (j >> 1) * width, u = 0, v = 0;
      for (int i = 0; i < width; i++, yp++) {
        int y = (0xff & yuv420sp[yp]) - 16;
        if (y < 0) y = 0;
        if ((i & 1) == 0) {
          v = (0xff & yuv420sp[uvp++]) - 128;
          u = (0xff & yuv420sp[uvp++]) - 128;
        }
        int y1192 = 1192 * y;
        int r = (y1192 + 1634 * v);
        int g = (y1192 - 833 * v - 400 * u);
        int b = (y1192 + 2066 * u);

        if (r < 0)
          r = 0;
        else if (r > 262143) r = 262143;
        if (g < 0)
          g = 0;
        else if (g > 262143) g = 262143;
        if (b < 0)
          b = 0;
        else if (b > 262143) b = 262143;

        // I don't know how these r, g, b values are defined, I'm just copying what you had bellow and
        // getting their 8-bit values.
        outImg.setPixelRgb(i, j, ((r << 6) & 0xff0000) >> 16,
            ((g >> 2) & 0xff00) >> 8, (b >> 10) & 0xff);
      }
    }
    return outImg;
  }

  // TODO method to convert CameraImage to Image
  img.Image convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;

    final yRowStride = cameraImage.planes[0].bytesPerRow;
    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    final image = img.Image(width: width, height: height);

    for (var w = 0; w < width; w++) {
      for (var h = 0; h < height; h++) {
        final uvIndex =
            uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
        final index = h * width + w;
        final yIndex = h * yRowStride + w;

        final y = cameraImage.planes[0].bytes[yIndex];
        final u = cameraImage.planes[1].bytes[uvIndex];
        final v = cameraImage.planes[2].bytes[uvIndex];

        image.data!.setPixelR(w, h, yuv2rgb(y, u, v)); //= yuv2rgb(y, u, v);
      }
    }
    return image;
  }

  int yuv2rgb(int y, int u, int v) {
    // Convert yuv pixel to rgb
    var r = (y + v * 1436 / 1024 - 179).round();
    var g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
    var b = (y + u * 1814 / 1024 - 227).round();

    // Clipping RGB values to be inside boundaries [ 0 , 255 ]
    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);

    return 0xff000000 |
        ((b << 16) & 0xff0000) |
        ((g << 8) & 0xff00) |
        (r & 0xff);
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  //TODO convert CameraImage to InputImage
  InputImage? getInputImage() {
    final camera = camDirec == CameraLensDirection.front
        ? widget.cameras[1]
        : widget.cameras[0];
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(frame!.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    if (frame!.planes.length != 1) return null;
    final plane = frame!.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(frame!.width.toDouble(), frame!.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Widget buildResult() {
    if (_scanResults == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator.adaptive(),
            SizedBox(height: 20),
            Text(
              "Please wait, your camera is initializing...",
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }
    final Size imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );
    CustomPainter painter = FaceDetectorPainter(
      imageSize,
      _scanResults,
      camDirec,
      _animationController.value,
    );
    _scanResults = [];

    return CustomPaint(
      painter: painter,
    );
  }

  //TODO toggle camera direction
  void _toggleCameraDirection() async {
    if (camDirec == CameraLensDirection.back) {
      camDirec = CameraLensDirection.front;
      description = widget.cameras[1];
    } else {
      camDirec = CameraLensDirection.back;
      description = widget.cameras[0];
    }
    if (isStreamingFrame) {
      await controller.stopImageStream();
    }
    if (mounted) {
      setState(() {
        controller;
      });
    }

    initializeCamera();
  }

  //TODO close all resources
  @override
  void dispose() {
    if (isStreamingFrame) {
      controller.stopImageStream();
    }
    controller?.dispose();
    faceDetector.close();
    _animationController.stop();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    size = MediaQuery.of(context).size;
    if (controller != null) {
      //TODO View for displaying the live camera footage
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: Container(
            child: (controller.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  )
                : Container(),
          ),
        ),
      );

      //TODO View for displaying rectangles around detected aces
      stackChildren.add(
        Positioned(
            top: 0.0,
            left: 0.0,
            width: size.width,
            height: size.height,
            child: buildResult()),
      );
    }

    //TODO View for displaying the bar to switch camera direction
    isStreamingFrame
        ? stackChildren.add(
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(100)),
                  child: IconButton(
                    icon: const Icon(
                      Icons.cached,
                      color: Colors.white,
                    ),
                    iconSize: 60,
                    color: Colors.black,
                    onPressed: () {
                      _toggleCameraDirection();
                    },
                  ),
                ),
              ),
            ),
          )
        : const SizedBox();

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
            margin: const EdgeInsets.only(top: 0),
            color: Colors.black,
            child: Stack(
              children: stackChildren,
            )),
      ),
    );
  }
}

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(
      this.absoluteImageSize, this.faces, this.camDire2, this.animationValue);

  final Size absoluteImageSize;
  final List<Recognition>? faces;
  final CameraLensDirection camDire2;
  final double animationValue; // Controlling the scanning effect

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.indigoAccent;

    // Paint for the scanning effect
    final Paint scanPaint = Paint()
      ..color = Colors.red.withOpacity(0.7) // Change to red color
      ..strokeWidth = 3.0;

    for (Recognition face in faces!) {
      // Drawing the face bounding box
      final Rect faceRect = Rect.fromLTRB(
        camDire2 == CameraLensDirection.front
            ? (absoluteImageSize.width - face.location.right) * scaleX
            : face.location.left * scaleX,
        face.location.top * scaleY,
        camDire2 == CameraLensDirection.front
            ? (absoluteImageSize.width - face.location.left) * scaleX
            : face.location.right * scaleX,
        face.location.bottom * scaleY,
      );

      canvas.drawRect(faceRect, paint);

      // Adding scanning effect within the bounding box
      // Calculate the scanning line's position
      final double linePositionY =
          faceRect.top + (faceRect.height * animationValue);

      // Ensure the line stays within the bounding box
      final double lineY = linePositionY.clamp(faceRect.top, faceRect.bottom);

      canvas.drawLine(
        Offset(faceRect.left, lineY),
        Offset(faceRect.right, lineY),
        scanPaint,
      );

      // Drawing the text (name and distance)
      TextSpan span = TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 20),
          text: "${face.name}  ${face.distance.toStringAsFixed(2)}");
      TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas,
          Offset(face.location.left * scaleX, face.location.top * scaleY));
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.camDire2 != camDire2 ||
        oldDelegate.animationValue !=
            animationValue; // Repaint when animation value changes
  }
}
