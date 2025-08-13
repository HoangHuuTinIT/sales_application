import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;


  Future<String?> uploadImageToFirebase(File imageFile) async {
    try {
      final fileName = DateTime
          .now()
          .millisecondsSinceEpoch
          .toString();
      final ref = _storage.ref().child('product_images/$fileName.jpg');

      // 🔻 Nén ảnh trước khi upload
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        quality: 70, // Tỉ lệ nén, có thể điều chỉnh (60-80)
      );

      if (compressedBytes == null) {
        print('❌ Không thể nén ảnh');
        return null;
      }

      final uploadTask = await ref.putData(Uint8List.fromList(compressedBytes));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Lỗi khi upload ảnh: $e');
      return null;
    }
  }
    Future<List<String>> uploadMultipleImages(List<File> images) async {
      List<String> imageUrls = [];
      for (final image in images) {
        final url = await uploadImageToFirebase(image);
        if (url != null) imageUrls.add(url);
      }
      return imageUrls;
    }


  Future<String?> addProduct({
    required String name,
    required String description,
    required double price,
    required int stockQuantity,
    required String categoryId,
    required List<String> imageUrls,
    required double discount,
    required DateTime discountStartDate,
    required DateTime discountEndDate,
    required double weight,  // 🆕
    required String code,    // 🆕
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final docRef = await _firestore.collection('Products').add({
        'name': name,
        'description': description,
        'price': price,
        'stockQuantity': stockQuantity,
        'categoryId': categoryId,
        'imageUrls': imageUrls,
        'discount': discount,
        'discountStartDate': discountStartDate,
        'discountEndDate': discountEndDate,
        'sold': 0,
        'weight': weight, // 🆕
        'code': code,     // 🆕
        'shopid': currentUser?.uid, // 🆕
        'createdAt': FieldValue.serverTimestamp(),
      });
      await docRef.update({'productId': docRef.id});
      return null;
    } catch (e) {
      return 'Lỗi khi thêm sản phẩm: $e';
    }
  }


  Future<String?> updateProduct({
    required String productId,
    required String name,
    required String description,
    required double price,
    required int stockQuantity,
    required String categoryId,
    List<String>? imageUrls,
    required double discount,
    required DateTime discountStartDate,
    required DateTime discountEndDate,
    required double weight, // 🆕
    required String code,   // 🆕
  }) async {
    try {
      final docRef = _firestore.collection('Products').doc(productId);
      final updateData = {
        'name': name,
        'description': description,
        'price': price,
        'stockQuantity': stockQuantity,
        'categoryId': categoryId,
        'discount': discount,
        'discountStartDate': discountStartDate,
        'discountEndDate': discountEndDate,
        'weight': weight, // 🆕
        'code': code,     // 🆕
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (imageUrls != null && imageUrls.isNotEmpty) {
        updateData['imageUrls'] = imageUrls;
      }
      await docRef.update(updateData);
      return null;
    } catch (e) {
      return 'Lỗi khi cập nhật sản phẩm: $e';
    }
  }


  Future<List<Map<String, dynamic>>> fetchAllProducts() async {
    try {
      final snapshot = await _firestore.collection('Products').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'price': data['price'],
          'image': (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty)
              ? data['imageUrls'][0]
              : null,
          'sold': data['sold'] ?? 0,  // ✅ Sửa ở đây
          'discount': data['discount'] ?? 0,
          'discountStartDate': data['discountStartDate']?.toDate(),
          'discountEndDate': data['discountEndDate']?.toDate(),
        };
      }).toList();
    } catch (e) {
      print('Lỗi khi lấy danh sách sản phẩm: $e');
      return [];
    }
  }



  Future<List<Map<String, dynamic>>> fetchProducts({
    String? categoryId,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];

      // Lấy shopid của user hiện tại
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final shopId = userDoc.data()?['shopid'];
      if (shopId == null) return [];

      // Truy vấn sản phẩm của shop này
      Query query = _firestore.collection('Products')
          .where('shopid', isEqualTo: shopId);

      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      query = query.orderBy('createdAt', descending: true);

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'productId': doc.id,
          'name': data['name'],
          'description': data['description'],
          'price': data['price'],
          'stockQuantity': data['stockQuantity'],
          'categoryId': data['categoryId'],
          'categoryName': data['categoryName'] ?? '',
          'imageUrls': List<String>.from(data['imageUrls'] ?? []),
          'discount': data['discount'] ?? 0,
          'discountStartDate': data['discountStartDate']?.toDate(),
          'discountEndDate': data['discountEndDate']?.toDate(),
          'weight': data['weight'],
          'code': data['code'],
        };
      }).toList();
    } catch (e) {
      print('Lỗi khi lấy sản phẩm: $e');
      return [];
    }
  }



  Future<String?> deleteProduct(String productId) async {
      try {
        await _firestore.collection('Products').doc(productId).delete();
        return null;
      } catch (e) {
        return 'Lỗi khi xóa sản phẩm: $e';
      }
    }
  Future<String?> deleteMultipleProducts(List<String> productIds) async {
    try {
      final batch = _firestore.batch();

      for (String id in productIds) {
        final docRef = _firestore.collection('Products').doc(id);
        batch.delete(docRef);
      }

      await batch.commit();
      return null;
    } catch (e) {
      return 'Lỗi khi xóa nhiều sản phẩm: $e';
    }
  }
  static Future<String> getProductNameById(String productId) async {
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore.collection('Products').doc(productId).get();
    if (doc.exists) {
      return doc.data()?['name'] ?? 'Không rõ';
    }
    return 'Không rõ';
  }

}

