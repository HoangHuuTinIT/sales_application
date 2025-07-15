import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:diacritic/diacritic.dart';

class BuyProductsService {
  final _ref = FirebaseFirestore.instance.collection('OrderedProducts');

  Future<void> createOrder({
    required String name,
    required String address,
    required String phone,
    required String productId, // ✅ Thêm
    required String productName,
    required double total,
    required int quantity,
    required String paymentMethod,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Người dùng chưa đăng nhập');

    final nameSearch = removeDiacritics(name).toLowerCase().trim();

    await _ref.add({
      'userId': user.uid,
      'name': name,
      'nameSearch': nameSearch,
      'address': address,
      'phone': phone,
      'productId': productId, // ✅ Thêm
      'productName': productName,
      'total': total,
      'quantity': quantity,
      'paymentMethod': paymentMethod,
      'status': 'Đang chờ xác nhận',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }


  Future<Map<String, dynamic>?> fetchUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return snapshot.data();
  }
}