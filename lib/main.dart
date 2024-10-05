import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:realtime_face_recognition/routes.dart';
import 'package:realtime_face_recognition/screens/home_page.dart';
import 'package:realtime_face_recognition/screens/mark_user_attendance.dart';
import 'package:realtime_face_recognition/screens/register_user.dart';

late List<CameraDescription> cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Geolocator.requestPermission();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        initialRoute: MyRoutes.homeRoute,
        routes: {
          MyRoutes.markAttendance: (context) => MarkUserAttendance(
                cameras: cameras,
              ),
          MyRoutes.registerRoute: (context) => RegisterUser(
                cameras: cameras,
              ),
          MyRoutes.homeRoute: (context) => const HomePage(),
        });
  }
}
