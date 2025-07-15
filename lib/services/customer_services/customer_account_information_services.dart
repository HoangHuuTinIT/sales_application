import 'dart:io';
import 'package:ban_hang/screens/customer/verify_phone_number.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img_lib;

class CustomerAccountInformationServices {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<void> updateAccountInfo({
    required String name,
    required String gender,
    required String province,
    required String district,
    required String ward,
    required String detailAddress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final fullAddress =
        "$detailAddress - $ward - $district - $province";

    await _firestore.collection('users').doc(user.uid).update({
      'name': name,
      'gender': gender,
      'address': fullAddress,
    });
  }

  Future<File?> pickImageFile() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final file = File(picked.path);

    // Resize
    final bytes = await file.readAsBytes();
    final image = img_lib.decodeImage(bytes);
    final resized = img_lib.copyResize(image!, width: 300);
    final resizedPath = '${file.parent.path}/resized_${file.uri.pathSegments.last}';
    final resizedFile = File(resizedPath)..writeAsBytesSync(img_lib.encodeJpg(resized, quality: 85));

    return resizedFile;
  }

  Future<String?> uploadAvatar(File file) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final ref = _storage.ref().child('avatars/${user.uid}.jpg');
    await ref.putFile(file);
    final downloadUrl = await ref.getDownloadURL();
    return downloadUrl;
  }

  Future<String?> verifyAndChangePhone(BuildContext context) async {
    final verifiedPhone = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VerifyPhoneNumberScreen(isForChange: true)),
    );


    if (verifiedPhone == null) return null;

    final user = _auth.currentUser;
    if (user == null) return null;

    await _firestore.collection('users').doc(user.uid).update({
      'phone': verifiedPhone,
    });

    return verifiedPhone;
  }

  Future<String?> verifyAndChangeEmail(BuildContext context) async {
    String? newEmail;

    await showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Nhập email mới'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Email mới',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final email = controller.text.trim();
                Navigator.of(context).pop(email);
              },
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    ).then((value) {
      newEmail = value;
    });

    if (newEmail == null) return null;

    final user = _auth.currentUser;
    if (user == null) return null;

    await _firestore.collection('users').doc(user.uid).update({
      'email': newEmail,
    });

    return newEmail;
  }

// Giữ nguyên các hàm đổi phone/email nếu có
}
