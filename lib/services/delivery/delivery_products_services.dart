import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryProductsServices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> get deliveryProductsStream {
    return _firestore
        .collection('delivery_products')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .where((doc) => (doc.data()['status'] ?? '') != 'Hoàn tất thanh toán')
        .map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList());
  }


  void loadDeliveryProducts() {
    // Chỉ để trigger StreamBuilder
  }

  /// 👉 Khi nhấn Vận chuyển
  Future<void> updateToTransporting(Map<String, dynamic> delivery) async {
    final deliveryId = delivery['id'];
    final productName = delivery['productName'];
    final nameCustomer = delivery['nameCustomer'];

    final now = DateTime.now();

    // 1️⃣ Update delivery_products: status + delivery_start_time
    await _firestore.collection('delivery_products').doc(deliveryId).update({
      'status': 'Đang vận chuyển',
      'delivery_start_time': now,
    });

    // 2️⃣ Update OrderedProducts: status = Đang vận chuyển
    final orderedSnapshot = await _firestore
        .collection('OrderedProducts')
        .where('productName', isEqualTo: productName)
        .where('name', isEqualTo: nameCustomer)
        .get();

    for (var doc in orderedSnapshot.docs) {
      await doc.reference.update({'status': 'Đang vận chuyển'});
    }
  }


  /// 👉 Khi nhấn Hoàn tất
  Future<void> completeDelivery(Map<String, dynamic> delivery) async {
    final deliveryId = delivery['id'];
    final productName = delivery['productName'];
    final nameCustomer = delivery['nameCustomer'];
    final productId = delivery['productId'];
    final quantity = delivery['quantity'] as num;
    final total = delivery['total'] as num;
    final now = DateTime.now();

    // 1️⃣ Update delivery_products
    await _firestore.collection('delivery_products').doc(deliveryId).update({
      'status': 'Hoàn tất thanh toán',
      'delivery_end_time': now,
    });

    // 2️⃣ Update OrderedProducts
    final orderedSnapshot = await _firestore
        .collection('OrderedProducts')
        .where('productName', isEqualTo: productName)
        .where('name', isEqualTo: nameCustomer)
        .get();

    for (var doc in orderedSnapshot.docs) {
      await doc.reference.update({'status': 'Hoàn tất thanh toán'});
    }

    // 3️⃣ Thêm hoặc cộng dồn Products_sold
    final soldSnapshot = await _firestore
        .collection('Products_sold')
        .where('productId', isEqualTo: productId)
        .get();

    if (soldSnapshot.docs.isNotEmpty) {
      for (var doc in soldSnapshot.docs) {
        final currentData = doc.data();
        final oldTotal = currentData['total'] as num? ?? 0;
        final oldQuantity = currentData['quantity'] as num? ?? 0;

        await doc.reference.update({
          'total': oldTotal + total,
          'quantity': oldQuantity + quantity,
          'delivery_end_time': now,
        });
      }
    } else {
      await _firestore.collection('Products_sold').add({
        'productName': productName,
        'quantity': quantity,
        'status': 'Hoàn tất thanh toán',
        'total': total,
        'delivery_end_time': now,
        'productId': productId,
      });
    }

    // 4️⃣ Update Products.sold
    final productRef = _firestore.collection('Products').doc(productId);
    final productSnap = await productRef.get();
    if (productSnap.exists) {
      final currentData = productSnap.data()!;
      final currentSold = currentData['sold'] as num? ?? 0;

      await productRef.update({
        'sold': currentSold + quantity,
      });
    }
  }





}
