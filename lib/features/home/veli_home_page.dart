import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ eklendi
import 'package:ogrencim_nerede/features/veli/veli_profil_duzenle.dart';
import 'package:ogrencim_nerede/features/veli/servisim_nerede.dart';
import 'package:ogrencim_nerede/features/auth/pages/phone_login_page.dart';

class VeliHomePage extends StatefulWidget {
  const VeliHomePage({super.key});

  @override
  State<VeliHomePage> createState() => _VeliHomePageState();
}

class _VeliHomePageState extends State<VeliHomePage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _checkFirstVisit(); // ✅ ilk giriş kontrolü
  }

  /// 🔹 Uygulamaya ilk kez girildi mi kontrol et
  Future<void> _checkFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenMessage = prefs.getBool('veli_welcome_shown') ?? false;

    if (!hasSeenMessage) {
      await Future.delayed(const Duration(milliseconds: 500)); // sayfa yüklenince göstermek için
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sayın veli, hoş geldiniz 👋'),
          content: const Text(
            'Bu uygulamanın amacı, öğrencinizin servisini anlık olarak takip etmenize yardımcı olmaktır.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Tamam'),
            ),
          ],
        ),
      );

      // 🔹 Artık bir daha gösterilmesin
      await prefs.setBool('veli_welcome_shown', true);
    }
  }

  /// 🔹 Firestore'dan kullanıcı verisini çek
  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!mounted) return;

      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı bilgisi bulunamadı.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veri alınamadı: $e')),
      );
    }
  }

  Future<void> _openProfilDuzenle() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VeliProfilPage()),
    );
    if (!mounted) return;
    _fetchUserData();
  }

  ImageProvider _getProfileImage() {
    if (_userData?['photoUrl'] != null && _userData!['photoUrl'].toString().isNotEmpty) {
      return NetworkImage(_userData!['photoUrl']);
    }
    return const AssetImage('assets/images/profile.png');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Veli Paneli'),
        actions: [
       
         IconButton(
  icon: const Icon(Icons.logout),
  onPressed: () async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Çıkış yapıldı')),
    );

    // 🔹 Giriş sayfasına yönlendir
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PhoneLoginPage()),
      (route) => false, // önceki tüm sayfaları kapatır
    );
  },
),

        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('Kullanıcı verisi bulunamadı'))
              : RefreshIndicator(
                  onRefresh: _fetchUserData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 70,
                          backgroundImage: _getProfileImage(),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _userData!['name'] ?? 'Ad soyad girilmedi',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _userData!['school'] ?? 'Okul belirtilmemiş',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        const Divider(thickness: 1),
                        const SizedBox(height: 16),
                        if (_userData!['tc'] != null && _userData!['tc'].toString().isNotEmpty)
                          Text(
                            "TC Kimlik No: ${_userData!['tc']}",
                            style: const TextStyle(fontSize: 15, color: Colors.black54),
                          ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _openProfilDuzenle,
                          icon: const Icon(Icons.edit),
                          label: const Text('Profilimi Düzenle'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ServisimNeredePageVeli()),
                            );
                          },
                          icon: const Icon(Icons.directions_bus, color: Colors.white),
                          label: const Text(
                            'Servis Nerede',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF44336),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
