import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/features/odeme_page.dart';

class SoforHomePage extends StatefulWidget {
  const SoforHomePage({super.key});

  @override
  State<SoforHomePage> createState() => _SoforHomePageState();
}

class _SoforHomePageState extends State<SoforHomePage> {
  bool _loading = true;
  bool _abonelikAktif = false;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionLocally();
  }

  Future<void> _checkSubscriptionLocally() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;
    final odemeTamam = data['odemeTamam'] ?? false;
    final baslangic = data['abonelikBaslangic'];
    final sureGun = data['abonelikSuresiGun'] ?? 30;

    bool aktif = false;

    if (odemeTamam && baslangic != null) {
      final endDate =
          (baslangic as Timestamp).toDate().add(Duration(days: sureGun));
      final now = DateTime.now();

      if (now.isBefore(endDate)) {
        aktif = true;
        debugPrint("🟢 Abonelik aktif (${endDate.difference(now).inDays} gün kaldı)");
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'odemeTamam': false});
        debugPrint("🔴 Abonelik süresi doldu, odemeTamam = false yapıldı");
      }
    }

    if (mounted) {
      setState(() {
        _abonelikAktif = aktif;
        _loading = false;
      });

      if (!aktif) {
        // 🟥 Abonelik bitmişse ödeme sayfasına yönlendir
        Future.microtask(() {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OdemePage()),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Şoför Ana Sayfa"),
        backgroundColor: const Color(0xFFF44336), // 🔴 #f44336 rengi
      ),
      body: Center(
        child: _abonelikAktif
            ? const Text("Hoşgeldin, aboneliğin aktif ✅")
            : const Text("Abonelik bulunamadı ❌"),
      ),
    );
  }
}
