import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class VeliProfilPage extends StatefulWidget {
  const VeliProfilPage({super.key});

  @override
  State<VeliProfilPage> createState() => _VeliProfilPageState();
}

class _VeliProfilPageState extends State<VeliProfilPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tcController = TextEditingController();
  final _schoolController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _completePhoneNumber;
  String? _role;
  XFile? _pickedFile;
  Uint8List? _webImage;
  String? _photoUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVeliData();
  }

  Future<void> _loadVeliData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();

      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _tcController.text = data['tc'] ?? '';
        _schoolController.text = data['school'] ?? '';
        _phoneController.text = (data['phone'] ?? '').replaceAll('+90', '').trim();
        _photoUrl = data['photoUrl'];
        _role = data['role'] ?? 'Veli';

        if (mounted) setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veli verisi yüklenemedi: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 30,
      );

      if (pickedFile == null) return;

      if (kIsWeb) {
        _webImage = await pickedFile.readAsBytes();
      }

      if (mounted) {
        setState(() => _pickedFile = pickedFile);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resim seçilemedi: $e')),
      );
    }
  }

  Future<String?> _uploadProfileImage(String uid) async {
    if (_pickedFile == null) return _photoUrl;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('veliler/$uid/profile_photos/$fileName');

    try {
      if (kIsWeb && _webImage != null) {
        await ref.putData(
          _webImage!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else if (!kIsWeb && _pickedFile != null) {
        await ref.putFile(File(_pickedFile!.path));
      }

      final downloadUrl = await ref.getDownloadURL();

      if (_photoUrl != null && _photoUrl!.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(_photoUrl!).delete();
        } catch (_) {}
      }

      if (mounted) setState(() => _photoUrl = downloadUrl);

      return downloadUrl;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resim yüklenemedi: $e')),
      );
      return null;
    }
  }

  Future<void> _saveVeliChanges() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isLoading = true);

  try {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) throw Exception('Kullanıcı UID bulunamadı.');

    final girilenTelefon = _completePhoneNumber?.replaceAll('+90', '').trim() ??
        _phoneController.text.replaceAll('+90', '').trim();

    if (girilenTelefon.isEmpty) {
      throw Exception('Telefon numarası zorunludur.');
    }

    // 📞 Aynı telefon başka kullanıcıda var mı kontrol et
    final phoneQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: girilenTelefon)
        .get();

    final phoneAlreadyExists = phoneQuery.docs.any((doc) => doc.id != uid);

    if (phoneAlreadyExists) {
      throw Exception(
          'Bu telefon numarası başka bir kullanıcıya ait. Lütfen farklı bir numara girin.');
    }

    final photoUrl = await _uploadProfileImage(uid);

    // 🔄 Firestore bilgilerini güncelle
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'name': _nameController.text.trim(),
      'tc': _tcController.text.trim(),
      'school': _schoolController.text.trim(),
      'phone': girilenTelefon,
      if (photoUrl != null) 'photoUrl': photoUrl,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Profil başarıyla güncellendi!')),
    );
    Navigator.pop(context);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Hata: $e')),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  ImageProvider _getProfileImage() {
    if (kIsWeb && _webImage != null) return MemoryImage(_webImage!);
    if (_pickedFile != null && !kIsWeb) {
      return FileImage(File(_pickedFile!.path));
    }
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return NetworkImage(_photoUrl!);
    }
    return const AssetImage('assets/images/profile.png');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Veli Profilim')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: _getProfileImage(),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 4,
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Ad Soyad'),
                      validator: (v) =>
                          v!.isEmpty ? 'Ad Soyad boş bırakılamaz' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tcController,
                      decoration:
                          const InputDecoration(labelText: 'TC Kimlik No'),
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'TC Kimlik No boş bırakılamaz';
                        } else if (v.length != 11) {
                          return 'TC 11 haneli olmalı';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _schoolController,
                      decoration: const InputDecoration(labelText: 'Okul Adı'),
                      validator: (v) =>
                          v!.isEmpty ? 'Okul adı boş bırakılamaz' : null,
                    ),
                    const SizedBox(height: 16),

                    // 📱 Telefon alanı
                  IntlPhoneField(
  controller: _phoneController,
  initialCountryCode: 'TR',
  showDropdownIcon: false, // ülke seçimi kapalı
  showCountryFlag: true,   // bayrak görünsün
  disableLengthCheck: true,
  decoration: const InputDecoration(
    labelText: 'Telefon Numarası',
    border: OutlineInputBorder(),
    counterText: '', // altındaki sayaç yazısını kaldırır
  ),
  onChanged: (phone) {
    _completePhoneNumber = phone.completeNumber; // +905xxxxxxxxx formatında
  },
  onSaved: (phone) {
    _completePhoneNumber = phone?.completeNumber;
  },
  validator: (value) {
    if (value == null || value.number.isEmpty) {
      return 'Telefon numarası boş bırakılamaz';
    }
    return null;
  },
),

                    const SizedBox(height: 16),
                    if (_role != null)
                      TextFormField(
                        readOnly: true,
                        initialValue: _role,
                        decoration: const InputDecoration(
                          labelText: 'Rol',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                      ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _saveVeliChanges,
                      icon: const Icon(Icons.save),
                      label: const Text('Kaydet'),
                      style: ElevatedButton.styleFrom(
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
