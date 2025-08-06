import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diacritic/diacritic.dart';

class OrderManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _normalizeText(String text) {
    return removeDiacritics(text).toLowerCase().trim();
  }

  Stream<QuerySnapshot> getOrdersStream({
    String? nameQuery,
    DateTime? dateFilter,
    String? statusFilter,
  }) {
    Query query = _firestore.collection('OrderedProducts');

    if (nameQuery != null && nameQuery.isNotEmpty) {
      final normalized = _normalizeText(nameQuery);
      query = query
          .orderBy('nameSearch') // BẮT BUỘC
          .where('nameSearch', isGreaterThanOrEqualTo: normalized)
          .where('nameSearch', isLessThanOrEqualTo: '$normalized\uf8ff');
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

    if (nameQuery == null || nameQuery.isEmpty) {
      query = query.orderBy('createdAt', descending: true);
    }

    return query.snapshots();
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
