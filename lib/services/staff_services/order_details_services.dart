import 'package:cloud_firestore/cloud_firestore.dart';

class OrderDetailsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getOrderDetails(String orderId) {
    return _firestore
        .collection('OrderedProducts')
        .doc(orderId)
        .collection('OrderDetails')
        .snapshots();
  }
}
