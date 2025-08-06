// lib/services/facebook_services/facebook_auth_service.dart
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FacebookAuthService {
  Future<void> signInWithFacebook(BuildContext context) async {
    final result = await FacebookAuth.instance.login(
      permissions: [
        'email',
        'public_profile',
        'pages_show_list',
        'pages_read_engagement',
        'pages_manage_metadata',
        'pages_read_user_content',
        'pages_manage_posts',
      ],
      loginBehavior: LoginBehavior.nativeWithFallback,
    );

    if (result.status == LoginStatus.success) {
      final accessToken = result.accessToken;
      final userData = await FacebookAuth.instance.getUserData();
      final fbUserId = accessToken!.userId;

      final doc = FirebaseFirestore.instance.collection('facebook_live').doc(fbUserId);
      await doc.set({
        'fbUserId': fbUserId,
        'name': userData['name'],
        'email': userData['email'],
        'picture': userData['picture']['data']['url'],
        'accessToken': accessToken.token,
        'connected': false,
        'createdAt': FieldValue.serverTimestamp(),
      });


      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đăng nhập thành công")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đăng nhập thất bại")));
    }
  }

  Future<List<Map<String, dynamic>>> loadConnectedAccounts() async {
    final snapshot = await FirebaseFirestore.instance.collection('facebook_live').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
  Future<void> connectAccount(String fbUserId, String displayName) async {
    await FirebaseFirestore.instance.collection('facebook_live').doc(fbUserId).update({
      'connected': true,
      'name': displayName,
    });
  }


  Future<void> logout(String fbUserId) async {
    await FirebaseFirestore.instance.collection('facebook_live').doc(fbUserId).delete();
  }



}
