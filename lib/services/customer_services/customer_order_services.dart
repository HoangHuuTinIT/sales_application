import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 📌 Lấy danh sách đơn hàng của người dùng hiện tại (real-time, nhanh nhất)
  Stream<QuerySnapshot<Map<String, dynamic>>> getMyOrders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Chưa đăng nhập");
    }

    return _firestore
        .collection('Order')
        .where('customerId', isEqualTo: user.uid)
        .orderBy('invoiceDate', descending: true)
        .snapshots();
  }
  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    final doc = await _firestore.collection('Order').doc(orderId).get();
    if (!doc.exists) return [];
    final data = doc.data()!;
    if (data['items'] == null) return [];
    return List<Map<String, dynamic>>.from(data['items']);
  }
}
