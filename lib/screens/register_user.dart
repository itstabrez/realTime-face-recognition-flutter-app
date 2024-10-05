import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:realtime_face_recognition/ML/Recognition.dart';
import 'package:realtime_face_recognition/ML/Recognizer.dart';
import 'package:realtime_face_recognition/widget/widget_face_painter.dart';

class RegisterUser extends StatefulWidget {
  final List<CameraDescription> cameras;

  const RegisterUser({super.key, required this.cameras});

  @override
  State<RegisterUser> createState() => _RegisterUserState();
}

class _RegisterUserState extends State<RegisterUser> {
//TODO declare variables
  late ImagePicker imagePicker;
  File? _image;
  bool isLoading = false; // This variable is to track loading state

  //TODO declare detector
  late FaceDetector faceDetector;

  //TODO declare face recognizer
  late Recognizer recognizer;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    imagePicker = ImagePicker();

    //TODO initialize face detector
    final options = FaceDetectorOptions();
    faceDetector = FaceDetector(options: options);

    //TODO initialize face recognizer
    recognizer = Recognizer();
  }

  //TODO capture image using camera
  _imgFromCamera() async {
    XFile? pickedFile = await imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        doFaceDetection();
      });
    }
  }

  //TODO choose image using gallery
  _imgFromGallery() async {
    XFile? pickedFile =
        await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        doFaceDetection();
      });
    }
  }

  //TODO face detection code here
  List<Face> faces = [];
  doFaceDetection() async {
    setState(() {
      isLoading = true; // To Show loading indicator
    });
    //TODO remove rotation of camera images
    _image = await removeRotation(_image!);

    image = await _image?.readAsBytes();
    image = await decodeImageFromList(image);

    //TODO passing input to face detector and getting detected faces
    InputImage inputImage = InputImage.fromFile(_image!);
    faces = await faceDetector.processImage(inputImage);
    for (Face face in faces) {
      Rect faceRect = face.boundingBox;
      num left = faceRect.left < 0 ? 0 : faceRect.left;
      num top = faceRect.top < 0 ? 0 : faceRect.top;
      num right =
          faceRect.right > image.width ? image.width - 1 : faceRect.right;
      num bottom =
          faceRect.bottom > image.height ? image.height - 1 : faceRect.bottom;
      num width = right - left;
      num height = bottom - top;

      //TODO crop face
      final bytes = _image!
          .readAsBytesSync(); //await File(cropedFace!.path).readAsBytes();
      img.Image? faceImg = img.decodeImage(bytes!);
      img.Image faceImg2 = img.copyCrop(faceImg!,
          x: left.toInt(),
          y: top.toInt(),
          width: width.toInt(),
          height: height.toInt());

      Recognition recognition = recognizer.recognize(faceImg2, faceRect);
      setState(() {
        isLoading = false; // Hide loading indicator after processing
      });
      showFaceRegistrationDialogue(
          Uint8List.fromList(img.encodeBmp(faceImg2)), recognition);
    }
    drawRectangleAroundFaces();

    //TODO call the method to perform face recognition on detected faces
  }

  //TODO remove rotation of camera images
  removeRotation(File inputImage) async {
    final img.Image? capturedImage =
        img.decodeImage(await File(inputImage!.path).readAsBytes());
    final img.Image orientedImage = img.bakeOrientation(capturedImage!);
    return await File(_image!.path).writeAsBytes(img.encodeJpg(orientedImage));
  }

  //TODO perform Face Recognition

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

  //TODO draw rectangles
  var image;
  drawRectangleAroundFaces() async {
    image = await _image?.readAsBytes();
    image = await decodeImageFromList(image);
    print("${image.width}   ${image.height}");
    setState(() {
      image;
      faces;
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          isLoading
              ? SizedBox(
                  height: screenHeight / 2,
                  width: screenWidth,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "Please Wait Your image is processing",
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      CircularProgressIndicator(),
                    ],
                  ),
                )
              : image != null
                  ? Container(
                      margin: const EdgeInsets.only(
                          top: 60, left: 30, right: 30, bottom: 0),
                      child: FittedBox(
                        child: SizedBox(
                          width: image.width.toDouble(),
                          height: image.width.toDouble(),
                          child: CustomPaint(
                            painter:
                                FacePainter(facesList: faces, imageFile: image),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.only(top: 100),
                      child: Image.asset(
                        "images/logo.png",
                        width: screenWidth - 100,
                        height: screenWidth - 100,
                      ),
                    ),

          Container(
            height: 50,
          ),

          //TODO section which displays buttons for choosing and capturing images
          Container(
            margin: const EdgeInsets.only(bottom: 50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Card(
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(200))),
                  child: InkWell(
                    onTap: () {
                      _imgFromGallery();
                    },
                    child: SizedBox(
                      width: screenWidth / 2 - 70,
                      height: screenWidth / 2 - 70,
                      child: Icon(Icons.image,
                          color: Colors.blue, size: screenWidth / 7),
                    ),
                  ),
                ),
                Card(
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(200))),
                  child: InkWell(
                    onTap: () {
                      _imgFromCamera();
                    },
                    child: SizedBox(
                      width: screenWidth / 2 - 70,
                      height: screenWidth / 2 - 70,
                      child: Icon(Icons.camera,
                          color: Colors.blue, size: screenWidth / 7),
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}














//   // Declaration of different models
//   late ImagePicker imagePicker;
//   late FaceDetector faceDetector;
//   late Recognizer recognizer;
//   bool isLoading = false; // This variable is to track loading state

//   List<Face> faces = [];

//   @override
//   void initState() {
//     super.initState();
//     imagePicker = ImagePicker();
//     final options =
//         FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate);
//     faceDetector = FaceDetector(options: options);
//     recognizer = Recognizer();
//   }

//   File? _image;
//   //Capture Image logic
//   captureImage() async {
//     XFile? image = await imagePicker.pickImage(source: ImageSource.camera);
//     if (image != null) {
//       setState(() {
//         _image = File(image.path);
//         doFaceDetection();
//       });
//     }
//   }

//   //Face Detection logic
//   doFaceDetection() async {
//     setState(() {
//       isLoading = true; // To Show loading indicator
//     });
//     InputImage inputImage = InputImage.fromFile(_image!);

//     //FACE DETECTION
//     faces = await faceDetector.processImage(inputImage);
//     // image = await _image?.readAsBytes();
//     image = await decodeImageFromList(_image!.readAsBytesSync());
//     for (Face face in faces) {
//       final Rect boundingBox = face.boundingBox;
//       print("Face Detected");
//       print("Rect = " + boundingBox.toString());

//       num left = boundingBox.left < 0 ? 0 : boundingBox.left;
//       num top = boundingBox.top < 0 ? 0 : boundingBox.top;
//       num right =
//           boundingBox.right > image.width ? image.width - 1 : boundingBox.right;
//       num bottom = boundingBox.bottom > image.height
//           ? image.height - 1
//           : boundingBox.bottom;
//       num width = right - left;
//       num height = bottom - top;

//       final bytes = _image!.readAsBytesSync();
//       img.Image? faceImg = img.decodeImage(bytes);
//       img.Image? croppedFace = img.copyCrop(faceImg!,
//           x: left.toInt(),
//           y: top.toInt(),
//           width: width.toInt(),
//           height: height.toInt());
//       Recognition recognition = recognizer.recognize(croppedFace, boundingBox);

//       showFaceRegistrationDialogue(
//           Uint8List.fromList(img.encodeBmp(croppedFace)), recognition);
//     }
//     setState(() {
//       isLoading = false; // Hide loading indicator after processing
//     });
//     drawRectangleAroundFaces();
//   }

//   //Converting captured or selected image format to draw rectangle
//   var image;
//   drawRectangleAroundFaces() async {
//     print("${image.width}       ${image.height}");
//     setState(() {
//       image;
//       faces;
//     });
//   }

//   //TODO Face Registration Dialogue
//   TextEditingController textEditingController = TextEditingController();
//   showFaceRegistrationDialogue(Uint8List cropedFace, Recognition recognition) {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text("Face Registration", textAlign: TextAlign.center),
//         alignment: Alignment.center,
//         content: SizedBox(
//           height: 340,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               const SizedBox(
//                 height: 20,
//               ),
//               Image.memory(
//                 cropedFace,
//                 width: 200,
//                 height: 200,
//               ),
//               SizedBox(
//                 width: 200,
//                 child: TextField(
//                     controller: textEditingController,
//                     decoration: const InputDecoration(
//                         fillColor: Colors.white,
//                         filled: true,
//                         hintText: "Enter Name")),
//               ),
//               const SizedBox(
//                 height: 10,
//               ),
//               ElevatedButton(
//                   onPressed: () {
//                     recognizer.registerFaceInDB(
//                         textEditingController.text, recognition.embeddings);
//                     textEditingController.text = "";
//                     Navigator.pop(context);
//                     Navigator.of(context).pop(); // Go back to the main page
//                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//                       content: Text("Face Registered"),
//                     ));
//                   },
//                   style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue,
//                       minimumSize: const Size(200, 40)),
//                   child: const Text("Register"))
//             ],
//           ),
//         ),
//         contentPadding: EdgeInsets.zero,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     double screenWidth = MediaQuery.of(context).size.width;
//     double screenHeight = MediaQuery.of(context).size.height;
//     int imageWidth = image != null ? image.width : 40;
//     int imageHeight = image != null ? image.height : 50;
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Register Image"),
//       ),
//       body: isLoading
//           ? const Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   CircularProgressIndicator(),
//                   SizedBox(height: 20),
//                   Text("Please wait, your image is processing..."),
//                 ],
//               ),
//             )
//           : Stack(
//               children: [
//                 // Face icons at the top center with padding
//                 Positioned(
//                   top: 30, // 30 pixels from the top
//                   left: 0,
//                   right: 0,
//                   child: Center(
//                     child: _image != null
//                         ? FittedBox(
//                             child: SizedBox(
//                               height: imageHeight.toDouble(),
//                               width: imageWidth.toDouble(),
//                               child: CustomPaint(
//                                 painter: FacePainter(
//                                   facesList: faces,
//                                   imageFile: image,
//                                 ),
//                               ),
//                             ),
//                           )
//                         : Image.asset(
//                             "assets/icons/face.png",
//                             height: screenHeight / 2.8,
//                             width: screenWidth / 1.5,
//                           ),
//                   ),
//                 ),

//                 // Capture Image button at the bottom center
//                 Positioned(
//                   bottom: 50, // 30 pixels from the bottom
//                   left: 0,
//                   right: 0,
//                   child: Center(
//                     child: roundedContainer(context,
//                         child: InkWell(
//                           onTap: () => captureImage(),
//                           child: const Icon(
//                             Icons.camera,
//                             size: 50.0,
//                             color: Colors.blue,
//                           ),
//                         )),
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }
// }
