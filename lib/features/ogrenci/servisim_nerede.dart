import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

class ServisimNeredePage extends StatefulWidget {
  const ServisimNeredePage({super.key});

  @override
  State<ServisimNeredePage> createState() => _ServisimNeredePageState();
}

class _ServisimNeredePageState extends State<ServisimNeredePage> {
  bool _loading = true;
  bool _showPlakaForm = false;

  LatLng? _deviceLocation;
  LatLng? _driverLocation;
  Stream<DocumentSnapshot>? _driverStream;
  gmaps.GoogleMapController? _googleMapController;
  gmaps.BitmapDescriptor? _carIcon;

  final TextEditingController _plakaController = TextEditingController();
  String? _sonGuncellemeText;
  Map<String, dynamic>? _driverData; // 👈 Şoför bilgileri tutulacak

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
    _initializeTracking();
  }

  Future<void> _loadCarIcon() async {
   final icon = await gmaps.BitmapDescriptor.asset(
  ImageConfiguration(size: const Size(100, 100)),
  'assets/images/car_icon2.png',
);
    setState(() => _carIcon = icon);
  }

  Future<void> _initializeTracking() async {
    await _getDeviceLocation();
    await _listenToDriverLocation();
    setState(() => _loading = false);
  }

Future<void> _getDeviceLocation() async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⚠️ Lütfen konum servisini açın")),
    );
    return;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🚫 Konum izni verilmedi")),
    );
    return;
  }

  final pos = await Geolocator.getCurrentPosition();
  if (!mounted) return;
  setState(() => _deviceLocation = LatLng(pos.latitude, pos.longitude));

  Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  ).listen((p) {
    if (!mounted) return;
    setState(() => _deviceLocation = LatLng(p.latitude, p.longitude));
    _fitBothMarkers();
  });
}

  Future<void> _listenToDriverLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final servisPlaka = userDoc.data()?['servisPlaka'];

    if (servisPlaka == null || servisPlaka.toString().trim().isEmpty) {
      setState(() => _showPlakaForm = true);
      return;
    }

    final soforQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Şoför')
        .where('plaka', isEqualTo: servisPlaka)
        .limit(1)
        .get();

    if (soforQuery.docs.isEmpty) {
      setState(() => _showPlakaForm = true);
      return;
    }

    final soforRef = soforQuery.docs.first.reference;
    _driverStream = soforRef.snapshots();

    _driverStream!.listen((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      _driverData = data; // 👈 Şoför bilgilerini sakla

      final konum = data?['konum'];
      if (konum != null && konum['lat'] != null && konum['lng'] != null) {
        setState(() {
          _driverLocation = LatLng(konum['lat'] as double, konum['lng'] as double);
        });
        _fitBothMarkers();
      }

      // ⏰ Timestamp farkını hesapla
      final timestamp = data?['konum']?['timestamp'];
      if (timestamp != null && timestamp is Timestamp) {
        final fark = DateTime.now().difference(timestamp.toDate());
        String text;

        if (fark.inMinutes < 1) {
          text = "Az önce güncellendi";
        } else if (fark.inMinutes < 60) {
          text = "${fark.inMinutes} dakika önce güncellendi";
        } else if (fark.inHours < 24) {
          text = "${fark.inHours} saat önce güncellendi";
        } else {
          text = "Servis şoförü uygulamaya giriş yapmadı.";
        }

        setState(() => _sonGuncellemeText = text);
      } else {
        setState(() => _sonGuncellemeText = "Henüz konum bilgisi yok");
      }
    });
  }

 Future<void> _savePlaka() async {
  final plaka = _plakaController.text.trim().toUpperCase();

  if (plaka.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⚠️ Lütfen bir plaka girin.")),
    );
    return;
  }

  final query = await FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'Şoför')
      .where('plaka', isEqualTo: plaka)
      .limit(1)
      .get();

  if (!mounted) return; // 🔒 async işlemden sonra güvenli context kontrolü

  if (query.docs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("🚌 $plaka plakalı şoför bulunamadı.")),
    );
    return;
  }

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .update({'servisPlaka': plaka});

  if (!mounted) return; // 🔒 yine güvenli context kontrolü
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("✅ $plaka plakası eklendi.")),
  );

  setState(() {
    _showPlakaForm = false;
    _loading = true;
  });

  await _initializeTracking();
}

Future<void> _leaveTracking() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .update({'servisPlaka': null});

  if (!mounted) return; // 🔒 Ekran hala açık mı kontrol et

  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text("🚫 Takipten çıkıldı.")));

  setState(() {
    _showPlakaForm = true;
    _driverLocation = null;
    _sonGuncellemeText = null;
  });
}

  Future<void> _fitBothMarkers() async {
    if (_googleMapController == null || _deviceLocation == null || _driverLocation == null) return;

    final bounds = gmaps.LatLngBounds(
      southwest: gmaps.LatLng(
        _deviceLocation!.latitude < _driverLocation!.latitude
            ? _deviceLocation!.latitude
            : _driverLocation!.latitude,
        _deviceLocation!.longitude < _driverLocation!.longitude
            ? _deviceLocation!.longitude
            : _driverLocation!.longitude,
      ),
      northeast: gmaps.LatLng(
        _deviceLocation!.latitude > _driverLocation!.latitude
            ? _deviceLocation!.latitude
            : _driverLocation!.latitude,
        _deviceLocation!.longitude > _driverLocation!.longitude
            ? _deviceLocation!.longitude
            : _driverLocation!.longitude,
      ),
    );

    await _googleMapController!
        .animateCamera(gmaps.CameraUpdate.newLatLngBounds(bounds, 80));
  }

  /// 👇 Şoför Bilgileri BottomSheet
  void _showDriverInfo() {
    if (_driverData == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("📡 Şoför bilgileri yüklenemedi")));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final photoUrl = _driverData?['photoUrl'];
        final name = _driverData?['name'] ?? 'Bilinmiyor';
        final phone = _driverData?['phone'] ?? 'Yok';
        final plaka = _driverData?['plaka'] ?? 'Tanımsız';

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (photoUrl != null && photoUrl.toString().isNotEmpty)
                CircleAvatar(
                  radius: 45,
                  backgroundImage: NetworkImage(photoUrl),
                )
              else
                const CircleAvatar(
                  radius: 45,
                  child: Icon(Icons.person, size: 45),
                ),
              const SizedBox(height: 12),
              Text(name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("Plaka: $plaka",
                  style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 6),
              Text("Telefon: $phone",
                  style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap() {
    if (_driverLocation == null || _deviceLocation == null) {
      return const Center(
          child: Text("📍 Konum bilgisi yükleniyor...", style: TextStyle(fontSize: 16)));
    }

    final harita = kIsWeb
        ? FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                (_deviceLocation!.latitude + _driverLocation!.latitude) / 2,
                (_deviceLocation!.longitude + _driverLocation!.longitude) / 2,
              ),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ercan.ogrencim_nerede',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: _driverLocation!,
                  width: 20,
                  height: 20,
                  child: Image.asset('assets/images/car_icon.png'),
                ),
                Marker(
                  point: _deviceLocation!,
                  width: 25,
                  height: 25,
                  child:
                      const Icon(Icons.my_location, color: Colors.blue, size: 35),
                ),
              ]),
            ],
          )
        : gmaps.GoogleMap(
            onMapCreated: (controller) {
              _googleMapController = controller;
              _fitBothMarkers();
            },
            initialCameraPosition: gmaps.CameraPosition(
              target:
                  gmaps.LatLng(_deviceLocation!.latitude, _deviceLocation!.longitude),
              zoom: 14,
            ),
            markers: {
              if (_carIcon != null)
                gmaps.Marker(
                  markerId: const gmaps.MarkerId('driver'),
                  position: gmaps.LatLng(
                      _driverLocation!.latitude, _driverLocation!.longitude),
                  infoWindow: const gmaps.InfoWindow(title: "Servis Aracı"),
                  icon: _carIcon!,
                ),
              gmaps.Marker(
                markerId: const gmaps.MarkerId('me'),
                position: gmaps.LatLng(
                    _deviceLocation!.latitude, _deviceLocation!.longitude),
                infoWindow: const gmaps.InfoWindow(title: "Benim Konumum"),
                icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                    gmaps.BitmapDescriptor.hueAzure),
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          );

    return Stack(
      children: [
        Positioned.fill(child: harita),
        if (_sonGuncellemeText != null)
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _sonGuncellemeText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
       Positioned(
  bottom: 20,
  left: 0,
  right: 0,
  child: Center(
    child: FloatingActionButton.extended(
      backgroundColor: const Color(0xFFF44336), // 🔴 #f44336
      icon: const Icon(Icons.person, color: Colors.white),
      label: const Text(
        "Şoför Bilgileri",
        style: TextStyle(color: Colors.white),
      ),
      onPressed: _showDriverInfo,
    ),
  ),
),

      ],
    );
  }

  Widget _buildPlakaForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("🚐 Lütfen Servis Plakası Girin",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _plakaController,
            decoration: const InputDecoration(
              labelText: "Servis Plakası",
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _savePlaka, child: const Text("Kaydet ve Devam Et")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Servisim Nerede"),
        actions: [
          if (!_showPlakaForm)
            TextButton.icon(
              onPressed: _leaveTracking,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                "Takipten Çık",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _showPlakaForm
              ? _buildPlakaForm()
              : _buildMap(),
    );
  }
}
