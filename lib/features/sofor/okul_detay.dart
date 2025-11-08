import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ogrencim_nerede/features/sofor/servis_takip_page.dart';

class OkulDetayPage extends StatefulWidget {
  final String okulId;
  final String okulAdi;

  const OkulDetayPage({
    super.key,
    required this.okulId,
    required this.okulAdi,
  });

  @override
  State<OkulDetayPage> createState() => _OkulDetayPageState();
}

class _OkulDetayPageState extends State<OkulDetayPage> {
  final Map<String, bool> _seciliOgrenciler = {}; // 🔹 Seçili öğrenciler

  /// 🔹 Okuldaki öğrencileri getir
  Stream<QuerySnapshot<Map<String, dynamic>>> _getOgrenciler() {
    return FirebaseFirestore.instance
        .collection('okullar')
        .doc(widget.okulId)
        .collection('ogrenciler')
        .orderBy('ad')
        .snapshots();
  }

  /// 🔹 Yeni öğrenci ekleme
  Future<void> _addOgrenciDialog() async {
    final TextEditingController adController = TextEditingController();
    final TextEditingController ogrenciTelController = TextEditingController();
    final TextEditingController veliTelController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Yeni Öğrenci Ekle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: adController,
                  decoration: const InputDecoration(labelText: "Öğrenci Ad Soyad *"),
                ),
                TextField(
                  controller: ogrenciTelController,
                  decoration: const InputDecoration(labelText: "Öğrenci Telefon"),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: veliTelController,
                  decoration: const InputDecoration(labelText: "Veli Telefon"),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () async {
                final ad = adController.text.trim();
                final ogrTel = ogrenciTelController.text.trim();
                final veliTel = veliTelController.text.trim();

                if (ad.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Ad Soyad boş bırakılamaz")),
                  );
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('okullar')
                    .doc(widget.okulId)
                    .collection('ogrenciler')
                    .add({
                  'ad': ad,
                  'ogrenciTelefon': ogrTel,
                  'veliTelefon': veliTel,
                  'eklenmeTarihi': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text("Ekle"),
            ),
          ],
        );
      },
    );
 
  }

  /// 🔹 Öğrenci düzenleme
  Future<void> _editOgrenciDialog(String ogrenciId, Map<String, dynamic> data) async {
    final TextEditingController adController = TextEditingController(text: data['ad'] ?? '');
    final TextEditingController ogrTelController =
        TextEditingController(text: data['ogrenciTelefon'] ?? '');
    final TextEditingController veliTelController =
        TextEditingController(text: data['veliTelefon'] ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Öğrenciyi Düzenle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: adController,
                    decoration: const InputDecoration(labelText: "Ad Soyad *")),
                TextField(
                    controller: ogrTelController,
                    decoration: const InputDecoration(labelText: "Öğrenci Telefon"),
                    keyboardType: TextInputType.phone),
                TextField(
                    controller: veliTelController,
                    decoration: const InputDecoration(labelText: "Veli Telefon"),
                    keyboardType: TextInputType.phone),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
            ElevatedButton(
              onPressed: () async {
                final ad = adController.text.trim();
                final ogrTel = ogrTelController.text.trim();
                final veliTel = veliTelController.text.trim();

                if (ad.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Ad Soyad boş bırakılamaz")),
                  );
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('okullar')
                    .doc(widget.okulId)
                    .collection('ogrenciler')
                    .doc(ogrenciId)
                    .update({
                  'ad': ad,
                  'ogrenciTelefon': ogrTel,
                  'veliTelefon': veliTel,
                });

                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text("Kaydet"),
            ),
          ],
        );
      },
    );
  }

  /// 🔹 Öğrenci silme
  Future<void> _deleteOgrenci(String ogrenciId) async {
    await FirebaseFirestore.instance
        .collection('okullar')
        .doc(widget.okulId)
        .collection('ogrenciler')
        .doc(ogrenciId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.okulAdi), centerTitle: true),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getOgrenciler(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final ogrenciler = snapshot.data?.docs ?? [];
          if (ogrenciler.isEmpty) {
            return const Center(child: Text("Bu okulda henüz öğrenci yok."));
          }

          return ListView.builder(
            itemCount: ogrenciler.length,
            itemBuilder: (context, i) {
              final doc = ogrenciler[i];
              final data = doc.data();
              final ad = data['ad'] ?? 'İsimsiz';
              final ogrTel = data['ogrenciTelefon'] ?? '-';
              final veliTel = data['veliTelefon'] ?? '-';
              final isSelected = _seciliOgrenciler[doc.id] ?? false;

              return Card(
                color: Colors.white.withValues(alpha: 0.9),
                child: ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        _seciliOgrenciler[doc.id] = v ?? false;
                      });
                    },
                  ),
                  title: Text(ad),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Öğrenci Tel: $ogrTel"),
                      Text("Veli Tel: $veliTel"),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _editOgrenciDialog(doc.id, data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteOgrenci(doc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            backgroundColor: const Color(0xFFF44336),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.play_arrow),
            label: const Text("Servise Başla"),
            onPressed: () {
              final secilenler = _seciliOgrenciler.entries
                  .where((e) => e.value)
                  .map((e) => e.key)
                  .toList();

              if (secilenler.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Hiç öğrenci seçmediniz.")),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ServisTakipPage(
                    servisId: "sofor123servisID", // 🔹 Gerçek servis ID’si burada olmalı
                    okulId: widget.okulId,
                    okulAdi: widget.okulAdi,
                    secilenOgrenciler: secilenler,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            backgroundColor: Colors.orange,
            icon: const Icon(Icons.person_add),
            label: const Text("Öğrenci Ekle"),
            onPressed: _addOgrenciDialog,
          ),
        ],
      ),
    );
  }
}
