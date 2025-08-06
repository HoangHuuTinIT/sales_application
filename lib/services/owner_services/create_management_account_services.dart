import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateManagementAccountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> createAccount({
    required String name,
    required String email,
    required String phone,
    required String detailAddress,
    required String province,
    required String district,
    required String ward,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final fullAddress = '$detailAddress - $ward - $district - $province';

      await _firestore.collection('users').add({
        'name': name,
        'email': email,
        'phone': phone,
        'address': fullAddress,
        'role': 'manager',
        'status': 'đã duyệt',
        'createdAt': FieldValue.serverTimestamp(),
        'creator': user.uid,
      });

      return true;
    } catch (e) {
      print('Error creating account: $e');
      return false;
    }
  }
}
