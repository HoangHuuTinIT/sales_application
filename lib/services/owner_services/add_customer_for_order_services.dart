import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class AddCustomerForOrderServices {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<void> addCustomer(Map<String, dynamic> data, {File? avatarFile}) async {
    String? avatarUrl;

    // Nếu có chọn ảnh thì nén & upload
    if (avatarFile != null) {
      // Nén ảnh trước khi upload (giảm size còn khoảng 70–80%)
      final Uint8List? compressedBytes =
      await FlutterImageCompress.compressWithFile(
        avatarFile.absolute.path,
        minWidth: 720,
        minHeight: 720,
        quality: 50, // chất lượng còn 80%
      );

      if (compressedBytes != null) {
        final ref = _storage
            .ref()
            .child("customer_avatars/${DateTime.now().millisecondsSinceEpoch}.jpg");

        // Upload trực tiếp từ bytes thay vì file gốc
        await ref.putData(compressedBytes);
        avatarUrl = await ref.getDownloadURL();
      }
    }

    final customerData = {
      ...data,
      'avatarUrl': avatarUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final String name = data['name'];
    final String phone = data['phone'];
    final String shopId = data['shopid'];

    // 1. Kiểm tra khách đã tồn tại trong facebook_customer chưa
    final existingQuery = await _firestore
        .collection("facebook_customer")
        .where("name", isEqualTo: name)
        .where("phone", isEqualTo: phone)
        .limit(1)
        .get();

    DocumentReference customerRef;

    if (existingQuery.docs.isNotEmpty) {
      // Nếu đã có thì dùng lại ref cũ
      customerRef = existingQuery.docs.first.reference;
    } else {
      // Nếu chưa có -> tạo ref trước nhưng chưa set (dùng batch để set)
      customerRef = _firestore.collection("facebook_customer").doc();
    }

    // 2. Kiểm tra trong shop_facebook_customer đã có chưa
    final shopCustomerQuery = await _firestore
        .collection("shop_facebook_customer")
        .where("shopid", isEqualTo: shopId)
        .where("customerRef", isEqualTo: customerRef)
        .limit(1)
        .get();

    if (shopCustomerQuery.docs.isNotEmpty && existingQuery.docs.isNotEmpty) {
      // Cả 2 đều đã có -> không cần làm gì thêm
      return;
    }

    // 3. Batch write
    final batch = _firestore.batch();

    if (existingQuery.docs.isEmpty) {
      batch.set(customerRef, customerData);
    }

    if (shopCustomerQuery.docs.isEmpty) {
      final shopCustomerRef =
      _firestore.collection("shop_facebook_customer").doc();
      batch.set(shopCustomerRef, {
        "createdAt": FieldValue.serverTimestamp(),
        "customerRef": customerRef,
        "shopid": shopId,
      });
    }

    await batch.commit();
  }
}
