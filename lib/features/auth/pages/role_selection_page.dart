import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/features/auth/pages/sozlesme_page.dart';

class RoleSelectPage extends StatefulWidget {
  final User user;
  const RoleSelectPage({super.key, required this.user});

  @override
  State<RoleSelectPage> createState() => _RoleSelectPageState();
}

class _RoleSelectPageState extends State<RoleSelectPage> {
  String? _selectedRole;
  bool _isSaving = false;

  final Color appColor = const Color(0xFFF44336); // 🔹 #f44336 kırmızı

  Future<void> _saveRole() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen bir rol seçin.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .set({
        'phone': widget.user.phoneNumber,
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SozlesmePage(
            role: _selectedRole!,
            user: widget.user,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kayıt hatası: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = [
      {
        'title': 'Öğrenci',
        'subtitle': 'Ücretsiz',
        'icon': Icons.school,
      },
      {
        'title': 'Veli',
        'subtitle': 'Ücretsiz',
        'icon': Icons.family_restroom,
      },
      {
        'title': 'Şoför',
        'subtitle': '299,00 TL / ay',
        'icon': Icons.directions_bus,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Rol Seçimi"),
        centerTitle: true,
        backgroundColor: appColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              "Hangi hesabı açmak istiyorsunuz?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ...roles.map((role) {
              final isSelected = _selectedRole == role['title'];
              return GestureDetector(
                onTap: () => setState(() => _selectedRole = role['title'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? appColor.withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? appColor : Colors.grey.shade300,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        role['icon'] as IconData,
                        color: isSelected ? appColor : Colors.grey.shade700,
                        size: 36,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role['title'] as String,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? appColor : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              role['subtitle'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                color: role['title'] == 'Şoför'
                                    ? Colors.orange.shade700
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: appColor, size: 28),
                    ],
                  ),
                ),
              );
            }),
            const Spacer(),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveRole,
              style: ElevatedButton.styleFrom(
                backgroundColor: appColor, // 🔹 Ana renk değişti
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text(
                      "Kaydet ve Devam Et",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
