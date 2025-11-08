import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ServisTakipPage extends StatefulWidget {
  final String servisId;
  final String okulId;
  final String okulAdi;
  final List<String> secilenOgrenciler; // sadece id listesi

  const ServisTakipPage({
    super.key,
    required this.servisId,
    required this.okulId,
    required this.okulAdi,
    required this.secilenOgrenciler,
  });

  @override
  State<ServisTakipPage> createState() => _ServisTakipPageState();
}

class _ServisTakipPageState extends State<ServisTakipPage> {
  bool _servisBasladi = false;
  List<Map<String, dynamic>> _ogrenciler = [];

  @override
  void initState() {
    super.initState();
    _ogrencileriGetir();
  }

  /// 🔹 Firestore'dan seçilen öğrencileri ID ile getir
  Future<void> _ogrencileriGetir() async {
    final firestore = FirebaseFirestore.instance;
    final List<Map<String, dynamic>> temp = [];

    for (final ogrId in widget.secilenOgrenciler) {
      try {
        final doc = await firestore
            .collection('okullar')
            .doc(widget.okulId)
            .collection('ogrenciler')
            .doc(ogrId)
            .get();

        if (doc.exists) {
          temp.add({
            'id': doc.id,
            'ad': doc['ad'] ?? 'İsimsiz',
            'ogrenciTelefon': doc['ogrenciTelefon'] ?? '-',
            'veliTelefon': doc['veliTelefon'] ?? '-',
          });
        }
      } catch (_) {
        // Firestore hatası: sessiz geç
      }
    }

    if (!mounted) return;
    setState(() => _ogrenciler = temp);
  }

  /// 🔹 Servis başlat
  Future<void> _servisiBaslat() async {
    final servisEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servisEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📍 Lütfen konumu aktif edin.")),
      );
      return;
    }

    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
      if (izin == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🚫 Konum izni reddedildi.")),
        );
        return;
      }
    }

    if (izin == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("⚠️ Konum izni kalıcı olarak reddedildi.")),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _servisBasladi = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🚐 Servis başlatıldı!")),
    );
  }

  /// 🔹 Servisi durdur
  void _servisiDurdur() {
    if (!mounted) return;
    setState(() => _servisBasladi = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🛑 Servis durduruldu.")),
    );
  }

  /// 🔹 Öğrenciyi Firestore’a "teslim edildi" olarak kaydet + listeden sil
  Future<void> _ogrenciyiTeslimEt(int index, String teslimTuru) async {
    if (index < 0 || index >= _ogrenciler.length) return;
    final ogr = _ogrenciler[index];
    final firestore = FirebaseFirestore.instance;

    try {
      await firestore
          .collection('servisler')
          .doc(widget.servisId)
          .collection('teslim_edilenler')
          .doc(ogr['id'])
          .set({
        'ogrenciId': ogr['id'],
        'ad': ogr['ad'],
        'ogrenciTelefon': ogr['ogrenciTelefon'],
        'veliTelefon': ogr['veliTelefon'],
        'teslimDurumu': teslimTuru,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _ogrenciler.removeAt(index));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${ogr['ad']} $teslimTuru ✅")),
      );

      if (_ogrenciler.isEmpty && mounted) {
        _servisiTamamlaDialog();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Hata: ${e.toString()}")),
      );
    }
  }

  /// 🔹 Servis tamamlandı diyalogu
  void _servisiTamamlaDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Servis Tamamlandı 🎉"),
        content: const Text("Tüm öğrenciler bırakıldı!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _servisiDurdur();
            },
            child: const Text("Tamam"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.okulAdi} Servis Takip")),
      body: _servisBasladi
          ? (_ogrenciler.isEmpty
              ? const Center(child: Text("🎉 Tüm öğrenciler bırakıldı!"))
              : ListView.builder(
                  itemCount: _ogrenciler.length,
                  itemBuilder: (context, i) {
                    final ogr = _ogrenciler[i];
                    return Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ogr['ad'],
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text("Öğrenci Tel: ${ogr['ogrenciTelefon']}"),
                            Text("Veli Tel: ${ogr['veliTelefon']}"),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _ogrenciyiTeslimEt(
                                        i, "okula bırakıldı"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text("Okula Bıraktım"),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _ogrenciyiTeslimEt(i, "eve bırakıldı"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text("Eve Bıraktım"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ))
          : Center(
              child: ElevatedButton.icon(
                onPressed: _servisiBaslat,
                icon: const Icon(Icons.play_arrow),
                label: const Text("Servisi Başlat"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF44336),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
      floatingActionButton: _servisBasladi
          ? FloatingActionButton.extended(
              backgroundColor: const Color.fromARGB(255, 255, 17, 0),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.stop),
              label: const Text("Servisi Durdur"),
              onPressed: _servisiDurdur,
            )
          : null,
    );
  }
}
