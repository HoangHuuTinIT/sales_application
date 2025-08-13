import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diacritic/diacritic.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _normalizeText(String text) {
    return removeDiacritics(text).toLowerCase().trim();
  }

  Stream<QuerySnapshot> getOrdersStream({
    String? nameQuery,
    DateTime? dateFilter,
    String? statusFilter,
  }) async* {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Chưa đăng nhập");

    // 🔹 Lấy shopid của user hiện tại
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final shopId = (userDoc.data()?['shopid'] ?? '').toString().trim();

    if (shopId.isEmpty) throw Exception("Không tìm thấy shopid");

    Query query = _firestore
        .collection('OrderedProducts')
        .where('shopid', isEqualTo: shopId); // chỉ lấy đơn của shop này

    if (dateFilter != null) {
      final start = DateTime(dateFilter.year, dateFilter.month, dateFilter.day);
      final end = start.add(const Duration(days: 1));
      query = query
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end));
    }

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    // Sắp xếp mới nhất lên trước
    query = query.orderBy('createdAt', descending: true);

    yield* query.snapshots();
  }



  Future<List<Map<String, dynamic>?>> getUserAndProduct(
      String userId,
      String productId,
      ) async {
    final userSnapshot = await _firestore.collection('users').doc(userId).get();
    final productSnapshot = await _firestore.collection('Products').doc(productId).get();

    return [userSnapshot.data(), productSnapshot.data()];
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _firestore.collection('OrderedProducts').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
