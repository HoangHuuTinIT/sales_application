import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerOrderService {
  final _orders = FirebaseFirestore.instance.collection('OrderedProducts');
  final _products = FirebaseFirestore.instance.collection('Products');
  final _ordersCancelled = FirebaseFirestore.instance.collection('OrderCancelled');

  Stream<QuerySnapshot> getMyOrders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _orders.where('userId', isEqualTo: user.uid).snapshots();
  }

  Future<String?> getProductImage(String productName) async {
    final snapshot = await _products
        .where('name', isEqualTo: productName)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      final imageUrls = data['imageUrls'];
      if (imageUrls is List && imageUrls.isNotEmpty) {
        return imageUrls[0];
      }
    }
    return null;
  }

  /// ✅ Thêm hàm này: Lưu + Xoá
  Future<void> cancelOrderAndSave(String orderId) async {
    final docSnapshot = await _orders.doc(orderId).get();
    if (!docSnapshot.exists) return;

    final data = docSnapshot.data();
    if (data == null) return;

    final createdAt = data['createdAt'];
    final userId = data['userId'];
    final productId = data['productId'];

    // 👉 Lưu bản sao sang OrderCancelled (vẫn giữ thông tin)
    data['status'] = 'Đơn hàng bị hủy';
    data['cancelledAt'] = FieldValue.serverTimestamp();
    await _ordersCancelled.doc(orderId).set(data);

    // 👉 Update status bên delivery_products (lọc theo điều kiện)
    final deliverySnapshot = await FirebaseFirestore.instance
        .collection('delivery_products')
        .where('createdAt', isEqualTo: createdAt)
        .where('userId', isEqualTo: userId)
        .where('productId', isEqualTo: productId)
        .get();

    for (final doc in deliverySnapshot.docs) {
      await doc.reference.update({'status': 'Đơn hàng bị hủy'});
    }

    // 👉 Cuối cùng xoá trong OrderedProducts
    await _orders.doc(orderId).delete();
  }


}
