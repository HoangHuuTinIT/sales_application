import 'package:ban_hang/services/auth_services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vietnam_provinces/vietnam_provinces.dart';

class CustomerOrderServiceLive {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _authService = AuthService();
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
  Future<List<Map<String, dynamic>>> fetchCustomersByShopIdFromRef() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("Chưa đăng nhập");

      // 1. Lấy shopId của user hiện tại
      final userSnap = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userSnap.exists) throw Exception("Không tìm thấy user");
      final shopId = userSnap.data()?['shopid'];
      if (shopId == null) throw Exception("User không có shopId");

      // 2. Lấy danh sách shop_facebook_customer theo shopId
      final shopCustomerSnap = await _firestore
          .collection('shop_facebook_customer')
          .where('shopid', isEqualTo: shopId)
          .get();

      // 3. Từ mỗi customerRef, lấy dữ liệu facebook_customer
      List<Map<String, dynamic>> customers = [];
      for (var doc in shopCustomerSnap.docs) {
        final ref = doc.data()['customerRef'];
        if (ref is DocumentReference) {
          final customerSnap = await ref.get();
          if (customerSnap.exists) {
            final data = customerSnap.data() as Map<String, dynamic>;
            data['id'] = customerSnap.id;
            customers.add(data);
          }
        }
      }
      return customers;
    } catch (e) {
      throw Exception("Lỗi khi lấy danh sách khách hàng từ ref: $e");
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
  Future<void> updateFacebookCustomerByFbid(String fbid, Map<String, dynamic> formData) async {
    try {
      if (fbid.isEmpty) throw Exception("Thiếu fbid");

      // 1. Lấy document theo fbid
      final querySnapshot = await _firestore
          .collection('facebook_customer')
          .where('fbid', isEqualTo: fbid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception("Không tìm thấy khách hàng với fbid này");
      }

      final docRef = querySnapshot.docs.first.reference;
      final currentData = querySnapshot.docs.first.data();

      // 2. So sánh và chỉ update các trường thay đổi
      final Map<String, dynamic> updatedData = {};

      void checkAndUpdate(String key, dynamic newValue) {
        if (newValue != null && newValue.toString().trim().isNotEmpty && newValue != currentData[key]) {
          updatedData[key] = newValue;
        }
      }

      checkAndUpdate('name', formData['name']);
      checkAndUpdate('phone', formData['phone']);
      checkAndUpdate('facebook', formData['facebook']);
      checkAndUpdate('email', formData['email']);
      checkAndUpdate('address', formData['address']);

      // Thêm updatedAt để biết lúc nào sửa
      updatedData['updatedAt'] = FieldValue.serverTimestamp();

      // 3. Cập nhật (merge giữ nguyên các trường khác)
      await docRef.set(updatedData, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Lỗi khi cập nhật facebook_customer: $e");
    }
  }
  Future<List<Map<String, dynamic>>> loadProductsForCurrentUserByShopId() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("User chưa đăng nhập");
    }

    // Lấy shopid của user hiện tại
    final userSnap = await _firestore.collection('users').doc(currentUser.uid).get();
    if (!userSnap.exists) throw Exception("Không tìm thấy user");
    final shopId = userSnap.data()?['shopid'];
    if (shopId == null) throw Exception("User không có shopid");

    // Lấy sản phẩm có shopid trùng
    final snapshot = await _firestore
        .collection('Products')
        .where('shopid', isEqualTo: shopId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      final imageUrls = data['imageUrls'] as List<dynamic>?;
      data['imageUrls'] = imageUrls?.cast<String>() ?? [];
      return data;
    }).toList();
  }


  Future<List<Province>> initLocationData() async {
    await _authService.initLocations();
    return _authService.getProvinces();
  }

  Map<String, dynamic> parseAddressParts(String address, List<Province> provinces) {
    List<String> parts = address.split('-').map((e) => e.trim()).toList();

    if (parts.length < 4) {
      return {
        'detailAddress': address,
        'province': null,
        'districts': <District>[],
        'district': null,
        'wards': <Ward>[],
        'ward': null,
      };
    }

    String wardName = parts[1];
    String districtName = parts[2];
    String provinceName = parts[3];

    Province? selectedProvince = provinces.firstWhere(
          (p) => p.name == provinceName,
      orElse: () => provinces.first,
    );
    List<District> districts = _authService.getDistricts(selectedProvince.code);

    District? selectedDistrict = districts.firstWhere(
          (d) => d.name == districtName,
      orElse: () => districts.first,
    );
    List<Ward> wards = _authService.getWards(
      selectedProvince.code,
      selectedDistrict.code,
    );

    Ward? selectedWard = wards.firstWhere(
          (w) => w.name == wardName,
      orElse: () => wards.first,
    );

    return {
      'detailAddress': parts.first,
      'province': selectedProvince,
      'districts': districts,
      'district': selectedDistrict,
      'wards': wards,
      'ward': selectedWard,
    };
  }
  Map<String, String> parseAddressString(String fullAddress) {
    final parts = fullAddress.split(' - ');

    // Lấy từng phần, nếu thiếu thì để ''
    final address = parts.isNotEmpty ? parts[0] : '';
    final area = parts.length > 1 ? parts[1] : '';
    final city = parts.length > 2 ? parts[2] : '';
    final prov = parts.length > 3 ? parts[3] : '';

    return {
      "address": address,
      "area": area,
      "city": city,
      "prov": prov,
    };
  }

}
