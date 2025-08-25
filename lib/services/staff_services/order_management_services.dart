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
  Future<Map<String, dynamic>?> prepareOrderData(String orderId) async {
    try {
      // Lấy dữ liệu từ OrderedProducts
      final orderDoc = await _firestore.collection('OrderedProducts').doc(orderId).get();
      if (!orderDoc.exists) return null;
      final orderData = orderDoc.data()!;

      final userId = orderData['userId'];
      if (userId == null) return null;

      // 🔹 Lấy thông tin user
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.exists ? userDoc.data()! : {};

      // 🔹 Lấy danh sách OrderDetails
      final detailsSnapshot = await _firestore
          .collection('OrderedProducts')
          .doc(orderId)
          .collection('OrderDetails')
          .get();

      final products = <Map<String, dynamic>>[];

      for (final d in detailsSnapshot.docs) {
        final p = d.data();

        // 🔹 Lấy thêm thông tin gốc từ Products
        final productDoc =
        await _firestore.collection('Products').doc(p['productId']).get();
        final productData = productDoc.data() ?? {};

        products.add({
          'name': p['productName'],
          'price': (p['price'] ?? 0).toDouble(),
          'quantity': p['quantity'] ?? 0,
          'stockQuantity': productData['stockQuantity'] ?? 0, // ✅ từ Products
          'weight': (productData['weight'] ?? 0).toDouble(), // ✅ từ Products
          'total': (p['total'] ?? 0).toDouble(),
          'imageUrls': productData['imageUrls'] ?? [], // ✅ ảnh sản phẩm
        });
      }

      // 🔹 Tính tổng
      final totalQuantity = products.fold<int>(0, (sum, p) => sum + (p['quantity'] as int));
      final totalWeight = products.fold<double>(0, (sum, p) => sum + (p['weight'] as double));
      final totalPrice = products.fold<double>(0, (sum, p) => sum + (p['total'] as double));

      // ✅ Gom dữ liệu thành customerData để truyền sang màn hình tạo đơn
      return {
        'id': userId,
        'name': userData['name'] ?? 'Chưa có tên',
        'phone': userData['phone'] ?? 'Chưa có số điện thoại',
        'address': userData['address'] ?? 'Chưa có địa chỉ',
        'avatarUrl': userData['avatarUrl'],
        'status': userData['status'] ?? 'Bình thường',
        'products': products,
        'totalQuantity': totalQuantity,
        'totalWeight': totalWeight,
        'totalPrice': totalPrice,
      };
    } catch (e) {
      print('❌ Lỗi prepareOrderData: $e');
      return null;
    }
  }


}
