import 'dart:convert';
import 'dart:typed_data' as typed;
import 'package:barcode/barcode.dart';
import 'package:barcode_image/barcode_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:diacritic/diacritic.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

class BuyProductsService {
  final _ref = FirebaseFirestore.instance.collection('OrderedProducts');

  Future<void> createOrder({
    required String productId,
    required double total,
    required int quantity,
    required String paymentMethod,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Người dùng chưa đăng nhập');

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(
        user.uid).get();
    final userData = userDoc.data();
    final name = userData?['name'] ?? '';

    final normalizedName = removeDiacritics(name).toLowerCase().trim();

    final docRef = _ref.doc(); // Tạo docRef trước để lấy ID
    await docRef.set({
      'orderedProductsId': docRef.id, // ✅ Lưu ID này vào chính tài liệu
      'userId': user.uid,
      'productId': productId,
      'total': total,
      'quantity': quantity,
      'paymentMethod': paymentMethod,
      'status': 'Đang chờ xác nhận',
      'createdAt': FieldValue.serverTimestamp(),
      'nameSearch': normalizedName,
    });
  }

  Future<Map<String, dynamic>?> fetchUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return snapshot.data();
  }

  Future<String> createOrderAndGetId({
    required String productId,
    required double total,
    required int quantity,
    required String paymentMethod,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Người dùng chưa đăng nhập');

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(
        user.uid).get();
    final userData = userDoc.data();
    final name = userData?['name'] ?? '';
    final normalizedName = removeDiacritics(name).toLowerCase().trim();

    final docRef = _ref.doc();
    await docRef.set({
      'orderedProductsId': docRef.id,
      'userId': user.uid,
      'productId': productId,
      'total': total,
      'quantity': quantity,
      'paymentMethod': paymentMethod,
      'status': 'Đang chờ xác nhận',
      'createdAt': FieldValue.serverTimestamp(),
      'nameSearch': normalizedName,
    });

    return docRef.id;
  }
  Future<void> createOrderWithBarcode({
    required String barcodeData,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      // Tạo ảnh mã vạch PNG
      final barcode = Barcode.code128();
      final image = img.Image(width: 400, height: 100);
      drawBarcode(
        image,
        barcode,
        barcodeData,
        x: 10,
        y: 10,
        width: 2,
        height: 80,
      );

      // Nếu cần: thêm text dưới barcode (bỏ nếu không cần)
      // img.drawString(image, img.arial_24, 10, 90, barcodeData);

      final List<int> bytes = img.encodePng(image);
      final typed.Uint8List pngBytes = typed.Uint8List.fromList(bytes);
      // Upload lên Firebase Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('barcodes/${DateTime.now().millisecondsSinceEpoch}.png');
      await ref.putData(pngBytes);
      final barcodeUrl = await ref.getDownloadURL();

      // Lưu đơn hàng vào Firestore
      final user = FirebaseAuth.instance.currentUser;
      final orderWithBarcode = {
        ...orderData,
        'userId': user?.uid,
        'barcodeData': barcodeData,
        'barcodeImageUrl': barcodeUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('OrderedProducts')
          .add(orderWithBarcode);

      print('✅ Đơn hàng đã được lưu cùng mã vạch!');
    } catch (e) {
      print('❌ Lỗi khi tạo đơn hàng với mã vạch: $e');
      rethrow;
    }
  }

}

