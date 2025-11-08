import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'features/auth/pages/phone_login_page.dart';
import 'features/auth/pages/role_selection_page.dart';
import 'features/home/ogrenci_home_page.dart';
import 'features/home/veli_home_page.dart';
import 'features/home/sofor_home_page.dart';
import 'features/home/yonetici_home_page.dart';
import 'features/odeme_page.dart';
import 'features/auth/pages/sozlesme_page.dart';

/// 🔔 Bildirim tanımı
final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel locationChannel = AndroidNotificationChannel(
  'location_channel',
  'Konum Servisi',
  description: 'Arka planda konum servisi bildirimi',
  importance: Importance.low,
);

/// 🔋 Batarya optimizasyonunu devre dışı bırak
Future<void> disableBatteryOptimization() async {
  const packageName = 'com.example.ogrencim_nerede';
  final isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;

  if (!isIgnoring) {
    await Permission.ignoreBatteryOptimizations.request();

    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      data: 'package:$packageName',
      flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }
}

/// 🔔 Bildirim sistemini başlat
Future<void> initializeNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(locationChannel);
}

/// 🔹 Giriş noktası
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await initializeNotifications();
    await initializeService();
  }

  runApp(const MyApp());
}

/// 🔹 Servis başlatma
Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  debugPrint("🚀 initializeService çalıştı");

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'location_channel',
    'Konum Servisi',
    description: 'Arka planda konum takibi bildirimi',
    importance: Importance.low,
  );

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: channel.id,
      initialNotificationTitle: '🚐 Konum Takibi',
      initialNotificationContent: 'Servis başlatılıyor...',
      foregroundServiceNotificationId: 999,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

/// 🔹 iOS arka plan işleyici
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  return true;
}

/// 🔹 Servis onStart
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  debugPrint("🚀 onStart çalıştı, foreground bildirimi ayarlanıyor...");

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: '🚐 Servis Takibi Aktif',
      content: 'Konum arka planda güncelleniyor...',
    );
  }

  final firestore = FirebaseFirestore.instance;

  service.on('setUser').listen((event) async {
    final uid = event?['uid'];
    if (uid == null) return;

    if (!await _checkLocationPermission()) {
      debugPrint("🚫 Konum izni verilmemiş.");
      return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      try {
        await firestore.collection('users').doc(uid).update({
          'konum': {
            'lat': pos.latitude,
            'lng': pos.longitude,
            'timestamp': FieldValue.serverTimestamp(),
          },
        });
        debugPrint("✅ Konum güncellendi: ${pos.latitude}, ${pos.longitude}");
      } catch (e) {
        debugPrint("⚠️ Konum güncellenemedi: $e");
      }
    });
  });
}

/// 🔹 Konum izni kontrolü
Future<bool> _checkLocationPermission() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return false;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return false;
  }
  return true;
}

/// 🔹 Ana Uygulama
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Öğrencim Nerede',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// 🔹 Kimlik kontrolü ve yönlendirme
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Map<String, dynamic>?> _getUserData(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) return doc.data();
    } catch (e) {
      debugPrint('Kullanıcı verisi alınamadı: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData) return const PhoneLoginPage();

        final user = snapshot.data!;

        return FutureBuilder<Map<String, dynamic>?>(
          future: _getUserData(user.uid),
          builder: (context, userSnapshot) {
  if (userSnapshot.connectionState == ConnectionState.waiting) {
    return const Scaffold(
        body: Center(child: CircularProgressIndicator()));
  }

  final data = userSnapshot.data;
  if (data == null) return RoleSelectPage(user: user);

  final role = data['role'] as String?;
  final sozlesmeOnay = data['sozlesmeOnay'] ?? false;
  final odemeTamam = data['odemeTamam'] ?? false;

  // 🔹 Rol yoksa role selection
  if (role == null) return RoleSelectPage(user: user);

  // 🔹 Sözleşme onaylanmadıysa sözleşme sayfasına yönlendir
  if (!sozlesmeOnay) {
    return SozlesmePage(user: user, role: role);
  }

  // 🔹 Sadece Şoför için ödeme kontrolü
  if (role == 'Şoför') {
    if (!odemeTamam) {
      return const OdemePage(); // ödeme yapılmamışsa ödeme ekranı
    } else {
      return SoforHomePage(); // ödeme yapılmışsa şoför ana sayfası
    }
  }

  // 🔹 Diğer roller (veli ve öğrenci) doğrudan ana sayfalarına gider
  switch (role) {
    case 'Öğrenci':
      return OgrenciHomePage();
    case 'Veli':
      return VeliHomePage();
    case 'Yonetici':
      return YoneticiHomePage();
    default:
      return Scaffold(
        body: Center(child: Text('Bilinmeyen rol: $role')),
      );
  }
},
        );
      },
    );
  }
}
