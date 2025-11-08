import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ogrencim_nerede/features/sofor/okul_detay.dart';

class ServisListemPage extends StatefulWidget {
  final String servisId;
  const ServisListemPage({super.key, required this.servisId});

  @override
  State<ServisListemPage> createState() => _ServisListemPageState();
}

class _ServisListemPageState extends State<ServisListemPage> {
  /// 🔹 Şoförün eklediği okulları getir
  Stream<QuerySnapshot<Map<String, dynamic>>> _getOkullar() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('okullar')
        .where('ekleyenId', isEqualTo: uid)
        .snapshots();
  }

  /// 🔹 Okul ekleme veya düzenleme dialogu
  Future<void> _addOrEditOkulDialog({String? okulId, String? mevcutAd}) async {
    final TextEditingController okulController =
        TextEditingController(text: mevcutAd ?? '');
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(okulId == null ? "Yeni Okul Ekle" : "Okulu Düzenle"),
          content: TextField(
            controller: okulController,
            decoration: const InputDecoration(hintText: "Okul adı girin"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () async {
                final ad = okulController.text.trim();
                if (ad.isEmpty) return;

                if (okulId == null) {
                  // 🔹 Yeni okul ekleme
                  await FirebaseFirestore.instance.collection('okullar').add({
                    'ad': ad,
                    'ekleyenId': uid,
                    'servisId': widget.servisId,
                    'eklenmeTarihi': FieldValue.serverTimestamp(),
                  });
                }else {
  // 🔹 Mevcut okulu düzenleme
  await FirebaseFirestore.instance
      .collection('okullar')
      .doc(okulId)
      .update({'ad': ad});
}

// 🔹 async işlem sonrası güvenli context kontrolü
if (!mounted) return;
Navigator.pop(context);

              },
              child: Text(okulId == null ? "Ekle" : "Kaydet"),
            ),
          ],
        );
      },
    );
  }

  /// 🔹 Okul silme
  Future<void> _deleteOkul(String okulId) async {
    await FirebaseFirestore.instance.collection('okullar').doc(okulId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Okul Listem"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getOkullar(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final okullar = snapshot.data?.docs ?? [];

          if (okullar.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Henüz okul eklenmemiş"),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                     style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF44336), // kırmızı zemin
                      foregroundColor: Colors.white,             // yazı (ikon) rengi
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text("Okul Ekle"),
                    onPressed: () => _addOrEditOkulDialog(),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: okullar.length,
            itemBuilder: (context, index) {
              final doc = okullar[index];
              final data = doc.data();
              final okulAdi = data['ad'] ?? 'İsimsiz Okul';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.school),
                  title: Text(okulAdi),
                  subtitle: Text("Servis ID: ${widget.servisId}"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OkulDetayPage(
                          okulId: doc.id,
                          okulAdi: okulAdi,
                        ),
                      ),
                    );
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _addOrEditOkulDialog(okulId: doc.id, mevcutAd: okulAdi),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteOkul(doc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
     floatingActionButton: FloatingActionButton.extended(
  onPressed: () => _addOrEditOkulDialog(),
  backgroundColor: const Color(0xFFF44336), 
  foregroundColor: Colors.white,             
  icon: const Icon(Icons.add),
  label: const Text("Okul Ekle"),
),

    );
  }
}
