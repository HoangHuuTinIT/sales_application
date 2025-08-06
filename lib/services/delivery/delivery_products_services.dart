import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryProductsServices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Không lọc status trong delivery_products nữa
  Stream<List<Map<String, dynamic>>> get deliveryProductsStream {
    return _firestore
        .collection('delivery_products')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList());
  }

  void loadDeliveryProducts() {
    // Không cần gì thêm, chỉ giữ để khởi động stream
  }

  /// Chuyển sang 'Đang vận chuyển' — chỉ update bên OrderedProducts
  Future<void> updateToTransporting(Map<String, dynamic> delivery) async {
    final orderedProductsId = delivery['orderedProductsId'];

    await _firestore.collection('OrderedProducts').doc(orderedProductsId).update({
      'status': 'Đang vận chuyển',
    });

    await _firestore.collection('delivery_products').doc(delivery['id']).update({
      'delivery_start_time': DateTime.now(),
    });
  }

  /// Hoàn tất giao hàng
  Future<void> completeDelivery(Map<String, dynamic> delivery) async {
    final deliveryId = delivery['id'];
    final orderedProductsId = delivery['orderedProductsId'];

    final orderedDoc =
    await _firestore.collection('OrderedProducts').doc(orderedProductsId).get();
    if (!orderedDoc.exists) return;

    final orderedData = orderedDoc.data()!;
    final productId = orderedData['productId'];
    final quantity = orderedData['quantity'] as num;

    // 1️⃣ Cập nhật status bên OrderedProducts
    await _firestore.collection('OrderedProducts').doc(orderedProductsId).update({
      'status': 'Hoàn tất thanh toán',
    });

    // 2️⃣ Cập nhật delivery_end_time bên delivery_products
    await _firestore.collection('delivery_products').doc(deliveryId).update({
      'delivery_end_time': DateTime.now(),
    });

    // 3️⃣ Lưu Products_sold
    await _firestore.collection('Products_sold').add({
      'orderedProductsId': orderedProductsId,
      'deliveryProductsId': deliveryId,
    });

    // 4️⃣ Update trường sold bên Products
    final productRef = _firestore.collection('Products').doc(productId);
    final productSnap = await productRef.get();
    if (productSnap.exists) {
      final oldSold = productSnap.data()?['sold'] as num? ?? 0;
      await productRef.update({'sold': oldSold + quantity});
    }
  }
}
