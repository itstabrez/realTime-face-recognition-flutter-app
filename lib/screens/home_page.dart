import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:realtime_face_recognition/main.dart';
import 'package:realtime_face_recognition/routes.dart';
import 'package:realtime_face_recognition/screens/mark_user_attendance.dart';
import 'package:realtime_face_recognition/screens/register_user.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Face Recognition App"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/icons/face.png",
              height: MediaQuery.of(context).size.height / 2.8,
              width: MediaQuery.of(context).size.width / 1.5,
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height / 5,
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, MyRoutes.registerRoute);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(screenWidth - 30, 50),
                backgroundColor: Colors.blue[100],
              ),
              child: const Text("Register Image"),
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, MyRoutes.markAttendance);
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(screenWidth - 30, 50),
                  backgroundColor: Colors.blue[100]),
              child: const Text("Mark Attendance"),
            )
          ],
        ),
      ),
    );
  }
}
