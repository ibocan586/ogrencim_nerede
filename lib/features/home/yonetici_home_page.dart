import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class YoneticiHomePage extends StatefulWidget {
  const YoneticiHomePage({super.key});

  @override
  State<YoneticiHomePage> createState() => _YoneticiHomePageState();
}

class _YoneticiHomePageState extends State<YoneticiHomePage> {
  final int _limit = 10;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _loading = false;
  List<DocumentSnapshot> _users = [];
  final ScrollController _scrollController = ScrollController();
  late String _adminUid;

  // 🆕 Rol filtreleme
  String _selectedRole = 'Tümü';
  final List<String> _roles = ['Tümü', 'Yönetici', 'Sürücü', 'Veli'];

  @override
  void initState() {
    super.initState();
    _checkIfAdmin();
  }

  /// 🔐 Yönetici kontrolü
  Future<void> _checkIfAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _redirectUnauthorized();
      return;
    }
    _adminUid = user.uid;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final role = doc.data()?['role'];
    if (role != 'yonetici' && role != 'Yonetici' && role != 'Yönetici') {
      _redirectUnauthorized();
      return;
    }

    _loadUsers();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loading &&
          _hasMore) {
        _loadUsers(loadMore: true);
      }
    });
  }

  void _redirectUnauthorized() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('❌ Bu sayfaya yalnızca yöneticiler erişebilir.')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    }
  }

  /// 🔄 Kullanıcıları yükle (filtreli)
  Future<void> _loadUsers({bool loadMore = false}) async {
    if (_loading || (!_hasMore && loadMore)) return;
    setState(() => _loading = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('users')
          .orderBy('name', descending: false)
          .limit(_limit);

      // 🆕 Rol filtresi uygulanıyor
      if (_selectedRole != 'Tümü') {
        query = query.where('role', isEqualTo: _selectedRole);
      }

      if (loadMore && _lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();

      setState(() {
        if (loadMore) {
          _users.addAll(snapshot.docs);
        } else {
          _users = snapshot.docs;
        }

        if (snapshot.docs.isNotEmpty) {
          _lastDoc = snapshot.docs.last;
        }

        if (snapshot.docs.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (e) {
      debugPrint('Hata: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  /// 🗑️ Kullanıcı silme işlemi
  Future<void> _deleteUser(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final uid = doc.id;

    if (uid == _adminUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Kendinizi silemezsiniz.")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kullanıcıyı sil'),
        content: Text(
            '${data['name'] ?? 'Bu kullanıcıyı'} silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

  try {
  await FirebaseFirestore.instance.collection('users').doc(uid).delete();

  if (!mounted) return; // ✅ widget hâlâ aktif mi kontrol et

  setState(() {
    _users.removeWhere((u) => u.id == uid);
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('✅ Kullanıcı başarıyla silindi.')),
  );
} catch (e) {
  if (!mounted) return; // ❗ hata kısmında da ekleyebilirsin
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Silme hatası: $e')),
  );
}

  }

  void _showUserDetails(Map<String, dynamic> data) {
    final konum = data['konum'];
    LatLng? position;

    if (konum != null && konum['lat'] != null && konum['lng'] != null) {
      position = LatLng(konum['lat'], konum['lng']);
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['name'] ?? 'Bilinmeyen',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Rol: ${data['role'] ?? '-'}'),
              const Divider(),
              ...data.entries.map((e) {
                if (['password', 'email', 'konum'].contains(e.key)) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('${e.key}: ${e.value}'),
                );
              }),
              const SizedBox(height: 16),
              if (position != null)
                SizedBox(
                  height: 250,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      initialCameraPosition:
                          CameraPosition(target: position, zoom: 15),
                      markers: {
                        Marker(
                          markerId: const MarkerId('userLocation'),
                          position: position,
                          infoWindow: InfoWindow(title: data['name'] ?? ''),
                        ),
                      },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                    ),
                  ),
                )
              else
                const Text(
                  '📍 Konum bilgisi bulunamadı.',
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👨‍💼 Yönetici Paneli'),
        actions: [
          // 🆕 Rol filtreleme dropdown
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRole,
              icon: const Icon(Icons.filter_list, color: Colors.white),
              dropdownColor: Colors.blueGrey[50],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedRole = value;
                  _users.clear();
                  _lastDoc = null;
                  _hasMore = true;
                });
                _loadUsers();
              },
              items: _roles
                  .map((r) =>
                      DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış yap',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
              }
            },
          ),
        ],
      ),
      body: _loading && _users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                _users.clear();
                _lastDoc = null;
                _hasMore = true;
                await _loadUsers();
              },
              child: _users.isEmpty
                  ? const Center(child: Text("Hiç kullanıcı bulunamadı"))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _users.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _users.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child:
                                Center(child: CircularProgressIndicator()),
                          );
                        }

                        final doc = _users[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'Bilinmeyen';
                        final role = data['role'] ?? 'Tanımsız';

                        return ListTile(
                          title: Text(name),
                          subtitle: Text(role),
                          leading:
                              const Icon(Icons.person_outline, color: Colors.blue),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.info_outline,
                                    color: Colors.blue),
                                onPressed: () => _showUserDetails(data),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteUser(doc),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
