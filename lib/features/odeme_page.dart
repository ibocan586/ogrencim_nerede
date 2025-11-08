import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🔹 Ana sayfalar
import '/features/auth/pages/phone_login_page.dart';
import '/features/home/ogrenci_home_page.dart';
import '/features/home/veli_home_page.dart';
import '/features/home/sofor_home_page.dart';

class OdemePage extends StatefulWidget {
  const OdemePage({super.key});

  @override
  State<OdemePage> createState() => _OdemePageState();
}

class _OdemePageState extends State<OdemePage> {
  final InAppPurchase _iap = InAppPurchase.instance;
  bool _loading = true;
  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  void initState() {
    super.initState();
    _initialize();
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdated);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    final available = await _iap.isAvailable();
    if (!available) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google Play faturalandırma kullanılabilir değil.")),
        );
      }
      return;
    }

    const ids = {'soforpro'};
    final response = await _iap.queryProductDetails(ids);

    if (response.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: ${response.error!.message}")),
        );
      }
    }

    setState(() {
      _products = response.productDetails;
      _loading = false;
    });
  }

  Future<void> _buy(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        await _handleSuccessfulPurchase();
        _iap.completePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ödeme hatası: ${purchase.error?.message}")),
          );
        }
      }
    }
  }

  Future<void> _handleSuccessfulPurchase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await userDoc.set({'odemeTamam': true}, SetOptions(merge: true));
    final doc = await userDoc.get();
    final role = doc.data()?['role'] ?? '';

    if (!mounted) return;

    Widget target;
    switch (role) {
      case 'Öğrenci':
        target = const OgrenciHomePage();
        break;
      case 'Veli':
        target = const VeliHomePage();
        break;
      case 'Şoför':
        target = const SoforHomePage();
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rol bilgisi bulunamadı.")),
        );
        return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => target),
      (route) => false,
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PhoneLoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Şoför Aboneliği"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color.fromARGB(255, 78, 78, 78)),
            tooltip: "Çıkış Yap",
            onPressed: _signOut,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.fromARGB(255, 202, 231, 255), Color.fromARGB(255, 103, 161, 208)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _products.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        "Ürün bulunamadı.\nLütfen uygulamayı Play Store’daki test bağlantısı ile indirdiğinizden emin olun.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Card(
                          color: Colors.white.withOpacity(0.95),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 10,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(Icons.star, size: 60, color: Color(0xFFF44336)),
                                const SizedBox(height: 16),
                                const Text(
                                  "Şoför Pro Aboneliği",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  "Uygulamaya abone olarak aracınızın canlı konumunu plakanız üzerinden veli ve öğrenciler ile paylaşın!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 15, color: Colors.black54),
                                ),
                                const SizedBox(height: 25),
                                ElevatedButton.icon(
                                  onPressed: () => _buy(_products.first),
                                  icon: const Icon(Icons.payment),
                                  label: Text(
                                    "${_products.first.price} / Aylık Satın Al",
                                    style: const TextStyle(fontSize: 17),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF44336),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "Abonelik Google Play üzerinden yönetilebilir.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
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
