
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PackagedProductServices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Map<String, dynamic>>> get packagedProductsStream {
    return _firestore
        .collection('OrderedProducts')
        .where('status', isEqualTo: 'Đóng gói hoàn tất')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // 👈 thêm id
      return data;
    }).toList());
  }


  void loadPackagedProducts() {
    // Chỉ để trigger StreamBuilder — có thể không cần code gì thêm
  }

  Future<void> acceptProduct(Map<String, dynamic> product) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data()!;

    await _firestore.collection('delivery_products').add({
      'productId': product['productId'],
      'nameDelivery': userData['name'],
      'phoneDelivery': userData['phone'],
      'emailDelivery': userData['email'],
      'productName': product['productName'],
      'quantity': product['quantity'],
      'total': product['total'],
      'nameCustomer': product['name'],
      'addressCustomer': product['address'],
      'phoneCustomer': product['phone'],
      'paymentMethod': product['paymentMethod'],
      'status': 'Shipper nhận hàng',
      'date_of_receipt': DateTime.now(),
      // 👉 Thêm createdAt gốc của OrderedProducts
      'createdAt': product['createdAt'],
      'userId' :product['userId'],
    });

    await _firestore
        .collection('OrderedProducts')
        .doc(product['id'])
        .update({'status': 'Shipper nhận hàng'});
  }


}
