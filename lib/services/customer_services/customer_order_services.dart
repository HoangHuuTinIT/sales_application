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

  Future<String?> getProductImage(String productId) async {
    final snapshot = await _products.doc(productId).get();
    if (snapshot.exists) {
      final data = snapshot.data();
      final imageUrls = data?['imageUrls'];
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

    // Cập nhật status đơn gốc
    await _orders.doc(orderId).update({
      'status': 'Đơn hàng bị hủy',
    });

    // Thêm OrderCancelled siêu gọn
    await _ordersCancelled.doc(orderId).set({
      'orderedProductsId': orderId,
      'cancelledAt': FieldValue.serverTimestamp(),
    });

    // Nếu cần, update delivery_products
    final data = docSnapshot.data();
    final createdAt = data?['createdAt'];
    final userId = data?['userId'];
    final productId = data?['productId'];

    final deliverySnapshot = await FirebaseFirestore.instance
        .collection('delivery_products')
        .where('createdAt', isEqualTo: createdAt)
        .where('userId', isEqualTo: userId)
        .where('productId', isEqualTo: productId)
        .get();

    for (final doc in deliverySnapshot.docs) {
      await doc.reference.update({'status': 'Đơn hàng bị hủy'});
    }
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    final doc = await _products.doc(productId).get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }


}
