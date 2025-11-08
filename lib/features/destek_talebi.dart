import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DestekTalebiPage extends StatefulWidget {
  const DestekTalebiPage({super.key});

  @override
  State<DestekTalebiPage> createState() => _DestekTalebiPageState();
}

class _DestekTalebiPageState extends State<DestekTalebiPage> {
  final TextEditingController _konuController = TextEditingController();
  final TextEditingController _mesajController = TextEditingController();

  bool _isSending = false;
  DateTime? _lastSendTime;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('device_id', id);
    }
    setState(() => _deviceId = id);
  }

  /// 🔹 Cihazın daha önce destek talebi olup olmadığını kontrol eder
  Future<bool> _hasExistingSupportRequest(String identifier) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('destek_talepleri')
        .where('identifier', isEqualTo: identifier)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// 🔹 Destek talebi gönderme işlemi
  Future<void> _sendSupportRequest() async {
    final konu = _konuController.text.trim();
    final mesaj = _mesajController.text.trim();

    if (konu.isEmpty || mesaj.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm alanları doldurun.")),
      );
      return;
    }

    if (_deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cihaz kimliği yüklenemedi. Lütfen tekrar deneyin.")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final identifier = user?.uid ?? _deviceId!;

    // 🔹 Aynı cihazdan daha önce talep gönderilmiş mi?
    final hasExisting = await _hasExistingSupportRequest(identifier);
    if (hasExisting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Zaten bir destek talebiniz bulunuyor. Lütfen yanıt bekleyin."),
        ),
      );
      return;
    }

    // 🔹 1 dakika kuralı (spam önleme)
    if (_lastSendTime != null &&
        DateTime.now().difference(_lastSendTime!) < const Duration(minutes: 1)) {
      final kalan = 60 - DateTime.now().difference(_lastSendTime!).inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lütfen $kalan saniye sonra tekrar deneyin.")),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final telefon = user?.phoneNumber ?? "Giriş yapılmadı";

      await FirebaseFirestore.instance.collection('destek_talepleri').add({
        'telefon': telefon,
        'uid': user?.uid ?? "Anonim",
        'identifier': identifier,
        'konu': konu,
        'mesaj': mesaj,
        'tarih': FieldValue.serverTimestamp(),
        'durum': 'beklemede',
      });

      _lastSendTime = DateTime.now();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Destek talebiniz başarıyla gönderildi ✅")),
      );

      _konuController.clear();
      _mesajController.clear();
    } catch (e) {
      debugPrint("Destek talebi hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bir hata oluştu: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text("Destek Talebi"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 2,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 🔹 Üst bilgi kartı
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: const [
                      Icon(Icons.support_agent, size: 60, color: Colors.blueAccent),
                      SizedBox(height: 10),
                      Text(
                        "Bir sorunla mı karşılaştınız?\nLütfen aşağıdaki formu doldurarak bize iletin.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // 🔹 Form kartı
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _konuController,
                        decoration: const InputDecoration(
                          labelText: "Konu",
                          prefixIcon: Icon(Icons.topic),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _mesajController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: "Mesajınız",
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.message_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              (_isSending || _deviceId == null) ? null : _sendSupportRequest,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.white),
                          label: Text(
                            _isSending ? "Gönderiliyor..." : "Gönder",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 5,
                            shadowColor: Colors.blueAccent.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ],
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
