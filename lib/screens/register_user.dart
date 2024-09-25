import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:realtime_face_recognition/ML/Recognition.dart';
import 'package:realtime_face_recognition/ML/Recognizer.dart';
import 'package:realtime_face_recognition/geofencing.dart';
import 'package:realtime_face_recognition/widget/widget_face_painter.dart';
import 'package:realtime_face_recognition/widget/widget_rounded_container.dart';

class RegisterUser extends StatefulWidget {
  final List<CameraDescription> cameras;

  const RegisterUser({super.key, required this.cameras});

  @override
  State<RegisterUser> createState() => _RegisterUserState();
}

class _RegisterUserState extends State<RegisterUser> {
  // Declaration of different models
  late ImagePicker imagePicker;
  late FaceDetector faceDetector;
  late Recognizer recognizer;

  List<Face> faces = [];

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();
    final options =
        FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate);
    faceDetector = FaceDetector(options: options);
    recognizer = Recognizer();
  }

  File? _image;
  //Capture Image logic
  captureImage() async {
    XFile? image = await imagePicker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _image = File(image.path);
        doFaceDetection();
      });
    }
  }

  //Face Detection logic
  doFaceDetection() async {
    InputImage inputImage = InputImage.fromFile(_image!);

    //FACE DETECTION
    faces = await faceDetector.processImage(inputImage);
    // image = await _image?.readAsBytes();
    image = await decodeImageFromList(_image!.readAsBytesSync());
    for (Face face in faces) {
      final Rect boundingBox = face.boundingBox;
      print("Face Detected");
      print("Rect = " + boundingBox.toString());

      num left = boundingBox.left < 0 ? 0 : boundingBox.left;
      num top = boundingBox.top < 0 ? 0 : boundingBox.top;
      num right =
          boundingBox.right > image.width ? image.width - 1 : boundingBox.right;
      num bottom = boundingBox.bottom > image.height
          ? image.height - 1
          : boundingBox.bottom;
      num width = right - left;
      num height = bottom - top;

      final bytes = _image!.readAsBytesSync();
      img.Image? faceImg = img.decodeImage(bytes);
      img.Image? croppedFace = img.copyCrop(faceImg!,
          x: left.toInt(),
          y: top.toInt(),
          width: width.toInt(),
          height: height.toInt());
      Recognition recognition = recognizer.recognize(croppedFace, boundingBox);
      showFaceRegistrationDialogue(
          Uint8List.fromList(img.encodeBmp(croppedFace)), recognition);
    }
    drawRectangleAroundFaces();
  }

  //Converting captured or selected image format to draw rectangle
  var image;
  drawRectangleAroundFaces() async {
    print("${image.width}       ${image.height}");
    setState(() {
      image;
      faces;
    });
  }

  //TODO Face Registration Dialogue
  TextEditingController textEditingController = TextEditingController();
  showFaceRegistrationDialogue(Uint8List cropedFace, Recognition recognition) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Face Registration", textAlign: TextAlign.center),
        alignment: Alignment.center,
        content: SizedBox(
          height: 340,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                height: 20,
              ),
              Image.memory(
                cropedFace,
                width: 200,
                height: 200,
              ),
              SizedBox(
                width: 200,
                child: TextField(
                    controller: textEditingController,
                    decoration: const InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        hintText: "Enter Name")),
              ),
              const SizedBox(
                height: 10,
              ),
              ElevatedButton(
                  onPressed: () {
                    recognizer.registerFaceInDB(
                        textEditingController.text, recognition.embeddings);
                    textEditingController.text = "";
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Face Registered"),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(200, 40)),
                  child: const Text("Register"))
            ],
          ),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    int imageWidth = image != null ? image.width : 40;
    int imageHeight = image != null ? image.height : 50;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register Image"),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _image != null
                ?
                //  Below code is used to show image in UI...

                // SizedBox(
                //     width: screenWidth / 1.5,
                //     height: screenHeight / 2,
                //     child: Image.file(_image!),
                //   )

                // Now we will draw a square paint in selected or captured image face\
                Container(
                    margin: const EdgeInsets.all(8.0),
                    child: FittedBox(
                      child: SizedBox(
                        height: imageHeight.toDouble(),
                        width: imageWidth.toDouble(),
                        child: CustomPaint(
                          painter: FacePainter(
                            facesList: faces,
                            imageFile: image,
                          ),
                        ),
                      ),
                    ),
                  )
                : Image.asset(
                    "assets/icons/face.png",
                    height: screenHeight / 2.8,
                    width: screenWidth / 1.5,
                  ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                roundedContainer(context,
                    child: InkWell(
                      onTap: () => captureImage(),
                      child: const Icon(
                        Icons.camera,
                        size: 50.0,
                        color: Colors.blue,
                      ),
                    )),
              ],
            )
          ],
        ),
      ),
    );
  }
}
