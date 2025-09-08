// lib/services/customer_services/purchased_products_services.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PurchasedProductsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Lấy các đơn hàng đã mua của user đang đăng nhập từ tất cả các shop
  Stream<QuerySnapshot<Map<String, dynamic>>> getPurchasedProducts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Trả về một stream rỗng nếu người dùng chưa đăng nhập
      return const Stream.empty();
    }

    // Sử dụng collectionGroup để truy vấn tất cả các collection con có tên 'sales'
    return _firestore
        .collectionGroup('sales')
    // Lọc các bản ghi có customerId khớp với ID của người dùng hiện tại
        .where('customerId', isEqualTo: user.uid)
    // Sắp xếp theo ngày thanh toán, đơn mới nhất lên đầu
        .orderBy('payment_date', descending: true)
        .snapshots();
  }
}