import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diacritic/diacritic.dart'; // ✅ Bỏ dấu tiếng Việt

class OrderManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔑 Bỏ dấu + lowercase
  String _normalizeText(String text) {
    return removeDiacritics(text).toLowerCase().trim();
  }

  /// 🔥 Lấy stream đơn hàng, có thể lọc tên, ngày, status cùng lúc
  Stream<QuerySnapshot> getOrdersStream({
    String? nameQuery,
    DateTime? dateFilter,
    String? statusFilter,
  }) {
    Query query = _firestore.collection('OrderedProducts');

    if (nameQuery != null && nameQuery.isNotEmpty) {
      final normalized = _normalizeText(nameQuery);
      query = query
          .where('nameSearch', isGreaterThanOrEqualTo: normalized)
          .where('nameSearch', isLessThanOrEqualTo: '$normalized\uf8ff')
          .orderBy('nameSearch');
    }

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

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots();
  }

  /// ✅ Cập nhật trạng thái đơn hàng
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _firestore.collection('OrderedProducts').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
