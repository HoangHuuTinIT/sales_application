// File: lib/services/forgot_password_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Kiểm tra email trong collection `users` rồi gửi email reset nếu tồn tại
  Future<String?> sendResetEmailIfUserExists(String email) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return 'Email chưa được đăng ký trong hệ thống';
      }

      await _auth.sendPasswordResetEmail(email: email);
      return null; // null tương ứng với không lỗi
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'Tài khoản Firebase chưa tồn tại';
      } else {
        return 'Gửi email thất bại: ${e.message}';
      }
    } catch (e) {
      return 'Lỗi không xác định: $e';
    }
  }
}
