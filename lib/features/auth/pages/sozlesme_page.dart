import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/features/odeme_page.dart';
import '/features/home/veli_home_page.dart';
import '/features/home/ogrenci_home_page.dart';

class SozlesmePage extends StatefulWidget {
  final User user;
  final String role; // 🔹 Rol eklendi

  const SozlesmePage({
    super.key,
    required this.user,
    required this.role,
  });

  @override
  State<SozlesmePage> createState() => _SozlesmePageState();
}

class _SozlesmePageState extends State<SozlesmePage> {
  bool _accepted = false;
  bool _saving = false;

  Future<void> _continue() async {
    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen sözleşmeyi onaylayın')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // 🔹 Firestore’a sözleşme onayını kaydet
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .set({'sozlesmeOnay': true}, SetOptions(merge: true));

      // 🔹 Rol bazlı yönlendirme
      if (widget.role == 'Şoför') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OdemePage()),
        );
        return;
      }

      Widget nextPage;
      switch (widget.role) {
        case 'Veli':
          nextPage = const VeliHomePage();
          break;
        case 'Öğrenci':
          nextPage = const OgrenciHomePage();
          break;
        default:
          nextPage = const Scaffold(
            body: Center(child: Text("Geçersiz rol")),
          );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextPage),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kullanım Sözleşmesi")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _getContractText(widget.role),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                ),
                const Expanded(
                  child: Text("Kullanım koşullarını kabul ediyorum"),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _saving ? null : _continue,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Devam Et"),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Rol'e göre farklı sözleşme metni göster
  String _getContractText(String role) {
    switch (role) {
      case 'Şoför':
        return "📄 Şoför Kullanım Sözleşmesi\n\n"
            "1. Konum bilgileriniz öğrencilerin güvenliği için alınır.\n"
            "2. Veriler yalnızca okul yönetimi ve veli ile paylaşılır.\n"
            "3. Araç konumu gizlilik ilkelerine uygun olarak korunur.\n"
            "4. Uygulamayı kullanarak bu şartları kabul etmiş olursunuz.";
      case 'Veli':
        return "📄 Veli Kullanım Sözleşmesi\n\n"
            "1. Çocuğunuzun servis konumunu görüntüleyebilirsiniz.\n"
            "2. Bilgiler yalnızca bilgilendirme amaçlıdır.\n"
            "3. Verileriniz üçüncü kişilerle paylaşılmaz.\n"
            "4. Uygulamayı kullanarak bu şartları kabul etmiş olursunuz.";
      case 'Öğrenci':
        return "📄 Öğrenci Kullanım Sözleşmesi\n\n"
            "1. Servis konum bilgileri yalnızca bilgilendirme amaçlıdır.\n"
            "2. Verileriniz gizli tutulur.\n"
            "3. Uygulamayı kullanarak bu şartları kabul etmiş olursunuz.";
      default:
        return "📄 Genel Kullanım Sözleşmesi\n\n"
            "Uygulamayı kullanarak gizlilik ve veri koruma ilkelerini kabul etmiş olursunuz.";
    }
  }
}
