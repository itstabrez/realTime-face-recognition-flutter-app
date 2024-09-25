import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class GeofencingService {
  final double targetLatitude;
  final double targetLongitude;
  final double radiusInMeters;
  final BuildContext context;

  GeofencingService({
    required this.context,
    required this.targetLatitude,
    required this.targetLongitude,
    this.radiusInMeters = 100.0, // Default radius of 100 meters
  });

  // Check if the device is within the geofenced area
  Future<void> checkDeviceInRange() async {
    bool isInRange = await _isWithinGeofence();

    if (!isInRange) {
      _showOutOfRangeDialog();
    }
  }

  // Get the current position of the device
  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _showLocationServicesDisabledDialog();
      return Future.error('Location services are disabled.');
    }

    // Check for location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // Get the current position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Determine if the device is within the geofence
  Future<bool> _isWithinGeofence() async {
    try {
      Position position = await _getCurrentPosition();

      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLatitude,
        targetLongitude,
      );

      return distanceInMeters <= radiusInMeters;
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }

  // Show dialog if the device is out of range
  void _showOutOfRangeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Out of Range'),
          content: Text('You are outside the allowed geofenced area.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Show a dialog when location services are disabled
  Future<void> _showLocationServicesDisabledDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Services Disabled'),
          content: Text('Please enable location services to continue.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                // Exit the app
                SystemNavigator.pop();
              },
            ),
          ],
        );
      },
    );
  }
}
