import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔹 Sayfa importları
import '/features/destek_talebi.dart';
import '/features/home/ogrenci_home_page.dart';
import '/features/home/veli_home_page.dart';
import '/features/home/sofor_home_page.dart';
import '/features/odeme_page.dart';
import '/features/auth/pages/role_selection_page.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  String _verificationId = '';
  bool _codeSent = false;
  bool _loading = false;
  String _fullPhone = '+90';
  int _secondsLeft = 0;
  Timer? _timer;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _showWelcomeMessage();
    _animController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _showWelcomeMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('welcome_shown') ?? false;
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school, size: 60, color: Colors.blue),
              const SizedBox(height: 12),
              const Text(
                "Hoşgeldiniz!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Bu uygulama öğrencilerin ve velilerin okul servislerini anlık takip edebilmesi için geliştirilmiştir.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Anladım"),
              ),
            ],
          ),
        ),
      );
      prefs.setBool('welcome_shown', true);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 180);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
      }
    });
  }

 Future<void> _sendCode() async {
  if (_secondsLeft > 0) return;
  if (_phoneController.text.trim().isEmpty ||
      _fullPhone.trim() == '+90' ||
      _fullPhone.trim().length < 10) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lütfen geçerli bir telefon numarası giriniz')),
    );
    return;
  }

  // 🔹 Ekranı hemen kod giriş sayfasına geçir
  setState(() {
    _codeSent = true;
    _loading = true;
  });

  try {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _fullPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
      },
      verificationFailed: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Hata oluştu')),
        );
        // 🔙 Başarısız olursa geri dön
        setState(() {
          _codeSent = false;
        });
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        _startCountdown();
      },
      codeAutoRetrievalTimeout: (id) {
        _verificationId = id;
      },
    );
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Telefon doğrulama başlatılamadı')),
    );
    setState(() {
      _codeSent = false;
    });
  }

  setState(() => _loading = false);
}

  // 🔹 Giriş kodunu doğrulayıp yönlendirme yapan metod
  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6 haneli doğrulama kodu giriniz')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _codeController.text.trim(),
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) throw Exception('Kullanıcı bulunamadı');

      // 🔍 Firestore'dan kullanıcı bilgisi al
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        // Kayıtlı değilse rol seçimine yönlendir
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => RoleSelectPage(user: user)),
            (route) => false,
          );
        }
        return;
      }

      final data = doc.data();
    final role = data?['role'] ?? '';
final odemeYapildi = data?['odemeYapildi'] ?? false;

// 🔸 Ödeme kontrolü sadece ŞOFÖR için yapılır
if (role == 'Şoför' && odemeYapildi == false) {
  if (mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OdemePage()),
      (route) => false,
    );
  }
  return;
}


      // 🔸 Role göre yönlendirme
      Widget targetPage;
      switch (role) {
        case 'Öğrenci':
          targetPage = const OgrenciHomePage();
          break;
        case 'Veli':
          targetPage = const VeliHomePage();
          break;
        case 'Şoför':
          targetPage = const SoforHomePage();
          break;
        default:
           targetPage = RoleSelectPage(user: user);
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => targetPage),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Doğrulama hatası: ${e.toString()}')),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF90CAF9), Color(0xFF42A5F5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Image.asset('assets/images/logo.png', height: 120),
                ),
                const SizedBox(height: 20),
                Text(
                  _codeSent ? "SMS Kodunu Gir" : "Telefon Numarası ile Giriş",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: !_codeSent
                      ? _buildPhoneInput(context)
                      : _buildCodeInput(context),
                ),
                const SizedBox(height: 20),
                if (_secondsLeft > 0)
                  LinearProgressIndicator(
                    value: _secondsLeft / 180,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : _codeSent
                            ? _verifyCode
                            : _sendCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 6,
                    ),
                    child: _loading
                        ? const Text("Giriş Yapılıyor...",
                            style: TextStyle(fontSize: 18))
                        : Text(
                            _codeSent
                                ? "Kodu Doğrula"
                                : _secondsLeft > 0
                                    ? "Tekrar kod gönder (${_secondsLeft}s)"
                                    : "Giriş Yap",
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_codeSent)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _codeSent = false;
                        _secondsLeft = 0;
                        _timer?.cancel();
                      });
                    },
                    child: const Text(
                      "Telefon numarasını değiştir",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                const SizedBox(height: 40),
               GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DestekTalebiPage()),
    );
  },
 child: DefaultTextStyle.merge(
    style: TextStyle(decoration: TextDecoration.none),
    child: Text(
      "💬 Destek Talebi",
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),

                const SizedBox(height: 30),
                const Text(
                  "Sürüm 1.0.0 • © 2025 Öğrencim Nerede",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput(BuildContext context) {
    return Card(
      key: const ValueKey('phone'),
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: IntlPhoneField(
          controller: _phoneController,
          initialCountryCode: 'TR',
          decoration: const InputDecoration(
            labelText: 'Telefon Numarası',
            border: OutlineInputBorder(),
          ),
          onChanged: (phone) => _fullPhone = phone.completeNumber,
        ),
      ),
    );
  }

  Widget _buildCodeInput(BuildContext context) {
    return Card(
      key: const ValueKey('code'),
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: "SMS Doğrulama Kodu",
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
      ),
    );
  }
}
