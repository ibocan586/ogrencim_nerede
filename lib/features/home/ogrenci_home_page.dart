import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ogrencim_nerede/features/ogrenci/ogrenci_profil_duzenle.dart';
import 'package:ogrencim_nerede/features/ogrenci/servisim_nerede.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ EKLENDİ
import 'package:ogrencim_nerede/features/auth/pages/phone_login_page.dart';


class OgrenciHomePage extends StatefulWidget {
  const OgrenciHomePage({super.key});

  @override
  State<OgrenciHomePage> createState() => _OgrenciHomePageState();
}

class _OgrenciHomePageState extends State<OgrenciHomePage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _showWelcomeMessageOnce(); // ✅ EKLENDİ
  }

  /// 🔹 Hoş geldiniz mesajını sadece ilk kez göster
  Future<void> _showWelcomeMessageOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('ogrenci_welcome_shown') ?? false;

    if (!hasShown) {
      await Future.delayed(const Duration(milliseconds: 600)); // Sayfa yüklenince ufak gecikme
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hoşgeldiniz 👋'),
          content: const Text(
            'Hoşgeldiniz, öğrencilik hayatınızı kolaylaştırmak için '
            'servisinizi anlık takip etmeniz için bu uygulamayı geliştirdik. '
            'Servisinin plakasını girerek anlık takip edebilirsin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );

      await prefs.setBool('ogrenci_welcome_shown', true); // ✅ Bir daha gösterme
    }
  }

  /// 🔹 Firestore'dan kullanıcı verisini çek
  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

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

  /// 🔹 Profil düzenleme sayfasını aç
  Future<void> _openProfilDuzenle() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilDuzenlePage()),
    );

    if (!mounted) return;
    _fetchUserData();
  }

  /// 🔹 Profil fotoğrafını doğru şekilde göster
  ImageProvider _getProfileImage() {
    if (_userData?['photoUrl'] != null &&
        _userData!['photoUrl'].toString().isNotEmpty) {
      return NetworkImage(_userData!['photoUrl']);
    }
    return const AssetImage('assets/images/profile.png');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenci Paneli'),
        actions: [
       
          IconButton(
            icon: const Icon(Icons.logout),
          onPressed: () async {
  await FirebaseAuth.instance.signOut();

  if (!mounted) return;

  // 🔹 Kullanıcıya bilgi mesajı
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Çıkış yapıldı')),
  );

  // 🔹 Giriş sayfasına yönlendir (PhoneLoginPage)
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const PhoneLoginPage()),
    (route) => false,
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
                          _userData!['name'] ?? 'Ad Soyad Yok',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _userData!['school'] ?? 'Okul belirtilmemiş',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        const Divider(thickness: 1),
                        const SizedBox(height: 16),
                        if (_userData!['tc'] != null &&
                            _userData!['tc'].toString().isNotEmpty)
                          Text(
                            "TC Kimlik No: ${_userData!['tc']}",
                            style: const TextStyle(
                                fontSize: 15, color: Colors.black54),
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
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ServisimNeredePage()),
                            );
                          },
                          icon: const Icon(Icons.directions_bus,
                              color: Colors.white),
                          label: const Text(
                            'Servisim Nerede',
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
