import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> addCategory({required String name}) async {
    try {
      final docRef = _firestore.collection('Categories').doc();
      await docRef.set({
        'categoryId': docRef.id,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null; // Thành công
    } catch (e) {
      return 'Lỗi khi thêm loại hàng: $e';
    }
  }

  // ✅ Thêm hàm này
  Future<List<Map<String, dynamic>>> fetchAllCategories() async {
    try {
      final snapshot = await _firestore.collection('Categories').get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc['categoryId'],
          'name': doc['name'],
        };
      }).toList();
    } catch (e) {
      print('Lỗi khi lấy danh sách loại hàng: $e');
      return [];
    }
  }

}
