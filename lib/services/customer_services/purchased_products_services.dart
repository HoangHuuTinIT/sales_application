import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PurchasedProductsService {
  final _orders = FirebaseFirestore.instance.collection('OrderedProducts');

  /// Lấy các đơn hàng đã mua (Hoàn tất thanh toán) của user đang đăng nhập
  Stream<QuerySnapshot> getPurchasedProducts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _orders
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'Hoàn tất thanh toán')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
