import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchEditableUsers() async {
    final snapshot = await _firestore
        .collection('users')
        .where('status', whereIn: ['đã duyệt', 'đã vô hiệu hóa'])
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> deleteUser(String userId) async {
    await _firestore.collection('users').doc(userId).update({'status': 'đã vô hiệu hóa'});
  }

  Future<void> restoreUser(String userId) async {
    await _firestore.collection('users').doc(userId).update({'status': 'đã duyệt'});
  }

  Future<void> updateUser(String userId, Map<String, dynamic> newData) async {
    await _firestore.collection('users').doc(userId).update(newData);
  }

  Map<String, String> parseAddress(String fullAddress) {
    final parts = fullAddress.split(' - ');
    return {
      'detail': parts.isNotEmpty ? parts[0] : '',
      'ward': parts.length > 1 ? parts[1] : '',
      'district': parts.length > 2 ? parts[2] : '',
      'province': parts.length > 3 ? parts[3] : '',
    };
  }

  String buildAddress(String detail, String ward, String district, String province) {
    return "$detail - $ward - $district - $province";
  }
}
