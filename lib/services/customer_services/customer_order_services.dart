import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 📌 Lấy danh sách đơn hàng của người dùng hiện tại (mới nhất trước)
  Stream<QuerySnapshot> getMyOrders() async* {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Chưa đăng nhập");

    yield* _firestore
        .collection('OrderedProducts')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// 📌 Lấy chi tiết sản phẩm và người dùng (nếu cần)
  Future<List<Map<String, dynamic>?>> getUserAndProduct(
      String userId,
      String productId,
      ) async {
    final userSnapshot = await _firestore.collection('users').doc(userId).get();
    final productSnapshot =
    await _firestore.collection('Products').doc(productId).get();
    return [userSnapshot.data(), productSnapshot.data()];
  }
}
