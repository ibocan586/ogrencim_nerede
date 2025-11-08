import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class HaritadaGosterPage extends StatefulWidget {
  const HaritadaGosterPage({super.key});

  @override
  State<HaritadaGosterPage> createState() => _HaritadaGosterPageState();
}

class _HaritadaGosterPageState extends State<HaritadaGosterPage> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  bool _isPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndStartTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

 Future<void> _checkPermissionAndStartTracking() async {
  final status = await Permission.location.request();

  if (!mounted) return; // 🔒 context güvenliği

  if (!status.isGranted) {
    setState(() => _isPermissionGranted = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("📍 Konum izni gerekli")),
    );
    return;
  }

  setState(() => _isPermissionGranted = true);
  _listenToLocationChanges();
}

  void _listenToLocationChanges() async {
    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    final mapController = await _controller.future;
    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition!, 16),
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((Position pos) async {
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
      });

      await mapController.animateCamera(
        CameraUpdate.newLatLng(_currentPosition!),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Haritada Göster")),
      body: !_isPermissionGranted
          ? const Center(child: Text("Konum izni bekleniyor..."))
          : _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!,
                    zoom: 16,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: {
                    Marker(
                      markerId: const MarkerId('me'),
                      position: _currentPosition!,
                      infoWindow: const InfoWindow(title: "Benim Konumum"),
                    ),
                  },
                  onMapCreated: (GoogleMapController controller) {
                    if (!_controller.isCompleted) {
                      _controller.complete(controller);
                    }
                  },
                ),
    );
  }
}
