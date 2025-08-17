import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShippingCompanyService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  Future<List<Map<String, dynamic>>> getAvailablePartners() async {
    final uid = _auth.currentUser!.uid;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final shopId = userDoc.data()?['shopid'];

    final partners = <Map<String, dynamic>>[];

    // Check JT_setting
    final jtDoc = await _firestore.collection('JT_setting').doc(shopId).get();
    if (jtDoc.exists) {
      partners.add({
        'name': 'J&T',
        'logoUrl': 'https://upload.wikimedia.org/.../j&t_logo.png', // placeholder
        ...jtDoc.data()!,
      });
    }

    // sau này có thể thêm Viettel Post, GHTK...
    return partners;
  }
}
