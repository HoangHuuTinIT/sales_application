import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SettingJAndTServices {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Lấy shopid của user đang đăng nhập từ bảng users
  static Future<String?> _getCurrentShopId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final userDoc = await _firestore.collection("users").doc(uid).get();
    if (!userDoc.exists) return null;

    return userDoc.data()?["shopid"]; // lấy field "shopid"
  }

  /// Lưu cấu hình mặc định
  static Future<void> saveDefaultConfig({
    required String apiAccount,
    required String customerCode,
    required String key,
    required String password,
    required String name,
    required String mobile,
    String? prov,
    String? city,
    String? area,
    required String address,
  }) async {
    final shopId = await _getCurrentShopId();
    if (shopId == null) {
      throw Exception("Không tìm thấy shopid cho user hiện tại");
    }

    final data = {
      "shopid": shopId,
      "apiAccount": dotenv.env['API_ACCOUNT'],
      "customerCode": customerCode,
      "key": key,
      "password": password,
      "name": name,
      "mobile": mobile,
      "prov": prov,
      "city": city,
      "area": area,
      "address": address,
      "nameCopany": 'J&T',
      "updatedAt": FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection("JT_setting")
        .doc(shopId)
        .set(data, SetOptions(merge: true));
  }

  /// Lưu cấu hình nâng cao
  static Future<void> saveAdvancedConfig({
    required String orderType,
    required String serviceType,
    required String payType,
    required String productType,
    required String goodsType,
    required String deliveryType,
    required String isInsured,
  }) async {
    final shopId = await _getCurrentShopId();
    if (shopId == null) {
      throw Exception("Không tìm thấy shopid cho user hiện tại");
    }

    final data = {
      "shopid": shopId,
      "orderType": orderType,
      "serviceType": serviceType,
      "payType": payType,
      "productType": productType,
      "goodsType": goodsType,
      "deliveryType": deliveryType,
      "isInsured": isInsured,
      "updatedAt": FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection("JT_setting")
        .doc(shopId)
        .set(data, SetOptions(merge: true));
  }
  static Future<Map<String, dynamic>?> getConfig() async {
    final shopId = await _getCurrentShopId();
    if (shopId == null) return null;

    final doc = await _firestore.collection("JT_setting").doc(shopId).get();
    if (!doc.exists) return null;

    return doc.data();
  }
}
