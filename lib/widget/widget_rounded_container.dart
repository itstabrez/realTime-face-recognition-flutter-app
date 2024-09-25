import 'package:flutter/material.dart';

Widget roundedContainer(BuildContext context, {required Widget child}) {
  final double screenWidth = MediaQuery.of(context).size.width;
  final double cardSize = screenWidth / 2.2 - 70;

  return Container(
    width: cardSize,
    height: cardSize,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      shape: BoxShape.circle,
      boxShadow: const [
        BoxShadow(
          color: Colors.grey,
          spreadRadius: 3,
          blurRadius: 7,
          offset: Offset(0, 3), // Shadow position
        ),
      ],
    ),
    child: child,
  );
}
