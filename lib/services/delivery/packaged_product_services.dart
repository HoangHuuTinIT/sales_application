import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PackagedProductServices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Map<String, dynamic>>> get packagedProductsStream async* {
    yield* _firestore
        .collection('OrderedProducts')
        .where('status', isEqualTo: 'Đóng gói hoàn tất')
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> results = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        results.add({
          'id': doc.id,
          'orderedProductsId': doc.id,
          'quantity': data['quantity'],
          'paymentMethod': data['paymentMethod'],
          'status': data['status'],
          'total': data['total'],
          'createdAt': data['createdAt'],
          'userId': data['userId'],
          'productId': data['productId'],
        });
      }

      return results;
    });
  }

  void loadPackagedProducts() {
    // Không cần gì thêm
  }

  Future<void> acceptProduct(Map<String, dynamic> product) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 👉 Bước 1: Thêm mới delivery_products KHÔNG chứa status nữa
    final docRef = await _firestore.collection('delivery_products').add({
      'orderedProductsId': product['orderedProductsId'],
      'deliveryId': user.uid,
      'date_of_receipt': DateTime.now(),
    });

    // Bước 2: Cập nhật lại chính nó để thêm deliveryProductsId
    await docRef.update({
      'deliveryProductsId': docRef.id,
    });

    // 👉 Bước 3: Update OrderedProducts -> status = 'Shipper nhận hàng'
    await _firestore
        .collection('OrderedProducts')
        .doc(product['id'])
        .update({'status': 'Shipper nhận hàng'});
  }


}
