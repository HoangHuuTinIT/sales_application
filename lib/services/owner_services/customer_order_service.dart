import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerOrderServiceLive {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Lấy danh sách khách hàng của user hiện tại, role = 'customer'
  Future<List<Map<String, dynamic>>> fetchCustomers(String currentUserId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('creatorId', isEqualTo: currentUserId)
          .where('role', isEqualTo: 'customer')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Lỗi khi lấy danh sách khách hàng: $e');
    }
  }

  /// Cập nhật hoặc tạo mới thông tin khách hàng trong bảng users
  Future<void> updateCustomerInfo(String userId, Map<String, dynamic> updatedData) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        // Cập nhật thông tin
        await docRef.update(updatedData);
      } else {
        // Tạo mới nếu chưa tồn tại
        await docRef.set(updatedData);
      }
    } catch (e) {
      throw Exception('Lỗi khi cập nhật thông tin khách hàng: $e');
    }
  }


  /// Kiểm tra user hiện tại có sản phẩm nào không
  Future<bool> hasProducts(String currentUserId) async {
    final snapshot = await _firestore
        .collection('Products')
        .where('creatorId', isEqualTo: currentUserId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Lấy danh sách sản phẩm của user hiện tại
  Future<List<Map<String, dynamic>>> fetchProducts(String currentUserId) async {
    final snapshot = await _firestore
        .collection('Products')
        .where('creatorId', isEqualTo: currentUserId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Thêm sản phẩm mới cho user
  Future<void> addProduct(String currentUserId, Map<String, dynamic> productData) async {
    productData['creatorId'] = currentUserId;
    await _firestore.collection('Products').add(productData);
  }
  Future<List<String>> fetchCategories() async {
    final snapshot = await _firestore.collection('Categories').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return data['name'] as String? ?? 'Không tên';
    }).toList();
  }

  Future<void> updateProduct(String productId, String creatorId, Map<String, dynamic> data) async {
    final docRef = _firestore.collection('Products').doc(productId);
    final doc = await docRef.get();
    if (doc.exists && doc.data()?['creatorId'] == creatorId) {
      await docRef.update(data);
    } else {
      throw Exception('Sản phẩm không tồn tại hoặc không thuộc về bạn');
    }
  }

  /// Xóa sản phẩm theo productId và creatorId
  Future<void> deleteProduct(String productId, String creatorId) async {
    final docRef = _firestore.collection('Products').doc(productId);
    final doc = await docRef.get();
    if (doc.exists && doc.data()?['creatorId'] == creatorId) {
      await docRef.delete();
    } else {
      throw Exception('Sản phẩm không tồn tại hoặc không thuộc về bạn');
    }
  }
  Future<List<Map<String, dynamic>>> loadProducts(String uid) async {
    final list = await fetchProducts(uid);
    return list.map((p) {
      final imageUrls = p['imageUrls'] as List<dynamic>?;
      return {
        ...p,
        'imageUrls': imageUrls?.cast<String>() ?? [],
      };
    }).toList();
  }
  Future<List<Map<String, dynamic>>> loadProductsForCurrentUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("User chưa đăng nhập");
    }

    final uid = currentUser.uid;
    final list = await fetchProducts(uid);

    return list.map((p) {
      final imageUrls = p['imageUrls'] as List<dynamic>?;
      return {
        ...p,
        'imageUrls': imageUrls?.cast<String>() ?? [],
      };
    }).toList();
  }

  // --- Hàm tìm kiếm sản phẩm ---
  List<Map<String, dynamic>> searchProducts(
      List<Map<String, dynamic>> allProducts,
      String query,
      ) {
    if (query.isEmpty) return List.from(allProducts);
    return allProducts
        .where((p) => (p['name'] ?? '')
        .toString()
        .toLowerCase()
        .contains(query.toLowerCase()))
        .toList();
  }

  // --- Hàm chọn hoặc bỏ chọn sản phẩm ---
  List<Map<String, dynamic>> toggleSelection(
      List<Map<String, dynamic>> selectedProducts,
      Map<String, dynamic> product,
      bool selected,
      ) {
    if (selected) {
      return [...selectedProducts, product];
    } else {
      return selectedProducts.where((p) => p['id'] != product['id']).toList();
    }
  }

  // --- Hàm xác nhận (ở service chỉ trả dữ liệu, UI tự Navigator.pop) ---
  List<Map<String, dynamic>> confirmSelection(
      List<Map<String, dynamic>> selectedProducts,
      ) {
    return selectedProducts;
  }

  // Hàm fetchProducts sẵn có không thay đổi
  Future<List<Map<String, dynamic>>> fetchProductsForSearchProducts(String currentUserId) async {
    final snapshot = await _firestore
        .collection('Products')
        .where('creatorId', isEqualTo: currentUserId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}
