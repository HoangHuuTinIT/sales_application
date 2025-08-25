import 'package:ban_hang/services/owner_services/printer_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:phone_number/phone_number.dart';

class FacebookLiveService {

  final PhoneNumberUtil _phoneNumberUtil = PhoneNumberUtil();

  Future<List<Map<String, dynamic>>> getLivestreams(String pageId,
      String accessToken) async {
    final url = Uri.parse(
        'https://graph.facebook.com/v19.0/$pageId/live_videos?access_token=$accessToken');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final liveVideos = data['data'] as List;
      return liveVideos.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception("Không thể lấy livestream");
    }
  }

  Future<List<Map<String, dynamic>>> getComments(String livestreamId,
      String accessToken) async {
    final url = Uri.parse(
      'https://graph.facebook.com/v19.0/$livestreamId/comments?fields=from{name,picture{url}},message,created_time&access_token=$accessToken',
    );
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final comments = data['data'] as List;
      return comments.map((c) => Map<String, dynamic>.from(c)).toList();
    } else {
      throw Exception("Không thể lấy comment");
    }
  }


  /// Lọc comment có chứa số điện thoại (dựa vào regex + chuẩn hóa nếu cần)
  Future<List<Map<String, dynamic>>> filterCommentsWithPhoneNumbers(
      List<Map<String, dynamic>> comments) async {
    final List<Map<String, dynamic>> result = [];

    // Regex tìm các cụm từ có thể là số điện thoại, cho phép dấu cách và gạch ngang
    final rawPhoneRegex = RegExp(r'[\d\s\-\+]{8,20}');

    for (final comment in comments) {
      final text = comment['message']?.toString() ?? '';

      final matches = rawPhoneRegex.allMatches(text);

      for (final match in matches) {
        String rawPhone = match.group(0)!;

        // Loại bỏ dấu cách, gạch ngang, chấm… => chỉ giữ lại chữ số và dấu +
        String cleanedPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');

        String normalizedPhone = cleanedPhone;

        // Nếu là số VN viết 0xxxxx thì chuyển thành +84xxxx
        if (cleanedPhone.startsWith('0') && cleanedPhone.length >= 9 &&
            cleanedPhone.length <= 10) {
          normalizedPhone = '+84${cleanedPhone.substring(1)}';
        } else if (cleanedPhone.startsWith('84') && cleanedPhone.length == 11) {
          normalizedPhone = '+$cleanedPhone';
        }

        try {
          final parsed = await _phoneNumberUtil.parse(normalizedPhone);
          final isValid = await _phoneNumberUtil.validate(
            normalizedPhone,
            regionCode: parsed.regionCode ?? 'VN',
          );

          if (isValid) {
            result.add(comment);
            break; // comment hợp lệ rồi, không cần kiểm tra tiếp số khác
          }
        } catch (_) {
          // Nếu parse lỗi thì bỏ qua
        }
      }
    }

    return result;
  }

  Future<void> createCustomerRecordsIfNotExists({
    required String fbid,
    required String name,
    required String? avatarUrl,
    required String creatorId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    // Lấy shopid của user hiện tại từ bảng users
    final currentUserDoc =
    await firestore.collection('users').doc(creatorId).get();
    final shopId = currentUserDoc.data()?['shopid'];
    if (shopId == null) {
      throw Exception('Không tìm thấy shopid của người dùng hiện tại');
    }

    // 1. Kiểm tra / tạo khách hàng trong facebook_customer
    DocumentReference customerRef;
    final fbCustomerQuery = await firestore
        .collection('facebook_customer')
        .where('fbid', isEqualTo: fbid)
        .limit(1)
        .get();

    if (fbCustomerQuery.docs.isEmpty) {
      // Chưa tồn tại → tạo mới
      final newDocRef = firestore.collection('facebook_customer').doc();
      await newDocRef.set({
        'name': name,
        'fbid': fbid,
        'avatarUrl': avatarUrl,
        'status': 'Bình thường',
        'creatorId': creatorId,
        'createdAt': Timestamp.now(),
        'phone_verified': true,
        'role': 'customer',
        'address': null,
        'phone': null,
      });
      customerRef = newDocRef;
    } else {
      // Đã tồn tại → lấy reference
      customerRef = fbCustomerQuery.docs.first.reference;
    }

    // 2. Kiểm tra trong shop_facebook_customer theo shopid + customerRef
    final shopFbCustomerQuery = await firestore
        .collection('shop_facebook_customer')
        .where('customerRef', isEqualTo: customerRef)
        .where('shopid', isEqualTo: shopId)
        .limit(1)
        .get();

    if (shopFbCustomerQuery.docs.isEmpty) {
      // Chưa tồn tại → thêm mới
      await firestore.collection('shop_facebook_customer').add({
        'customerRef': customerRef,
        'shopid': shopId,
        'createdAt': Timestamp.now(),
      });
    }
  }


  Future<List<Map<String, dynamic>>> loadComments(String livestreamId,
      String accessToken,) async {
    // Step 1: Get raw comments from Facebook
    final comments = await getComments(livestreamId, accessToken);

    // Step 2: Extract unique Facebook user IDs from comments
    final userIds = comments
        .map((c) => c['from']?['id'])
        .whereType<String>()
        .toSet();

    if (userIds.isEmpty) return comments;

    // Step 3: Fetch corresponding users from Firestore
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: userIds.toList())
        .get();

    final userMap = {
      for (var doc in usersSnapshot.docs) doc.id: doc.data(),
    };

    // Step 4: Assign status from Firestore to comments
    for (var comment in comments) {
      final fbId = comment['from']?['id'];
      if (fbId != null && userMap.containsKey(fbId)) {
        comment['status'] = userMap[fbId]?['status'];
      }
    }

    return comments;
  }

  Future<void> printComment({
    required String host, // IP máy in
    required int port, // Cổng máy in, thường là 9100
    required String userId,
    required String name,
    required String time,
    required String message,
  }) async {
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm58, profile);

    final PosPrintResult res = await printer.connect(host, port: port);

    if (res == PosPrintResult.success) {
      printer.text('--- Thông tin comment ---',
          styles: PosStyles(align: PosAlign.center, bold: true));
      printer.text('ID: $userId');
      printer.text('Tên: $name');
      printer.text('Thời gian: $time');
      printer.text('Nội dung: $message');
      printer.hr();
      printer.text('HHT',
          styles: PosStyles(align: PosAlign.center, bold: true));
      printer.cut();
      printer.disconnect();
    } else {

      throw Exception('Kết nối máy in thất bại: $res');

    }
  }

  Future<Map<String, dynamic>?> getPrinterForCurrentShop() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final firestore = FirebaseFirestore.instance;

    // 🔹 Lấy shopid từ bảng users
    final userDoc = await firestore.collection('users').doc(user.uid).get();
    final shopId = userDoc.data()?['shopid'];
    if (shopId == null) {
      debugPrint("⚠️ User chưa có shopid");
      return null;
    }

    // 🔹 Lấy máy in có shopid trùng khớp
    final query = await firestore
        .collection('printer')
        .where('shopid', isEqualTo: shopId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.data() as Map<String, dynamic>;
    }

    debugPrint("⚠️ Không tìm thấy máy in cho shopid: $shopId");
    return null;
  }

  Future<String> createOrderFromComment({
    required String userId,
    required String name,
    required String? avatarUrl,
    required String time,
    required String message,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('Chưa đăng nhập');

    // 1. Tạo customer record nếu chưa có
    await createCustomerRecordsIfNotExists(
      fbid: userId,
      name: name,
      avatarUrl: avatarUrl,
      creatorId: currentUserId,
    );

    // 2. Lấy máy in theo shopid
    final printerConfig = await getPrinterForCurrentShop();

    if (printerConfig != null) {
      final host = printerConfig['IP'] ?? '192.168.1.100';
      final port = (printerConfig['Port'] is int) ? printerConfig['Port'] : 9100;

      try {
        await printComment(
          host: host,
          port: port,
          userId: userId,
          name: name,
          time: time,
          message: message,
        );
        return "Tạo đơn thành công"; // ✅ có in thành công
      } catch (e) {
        debugPrint('❌ Lỗi khi in: $e');
        return "Thêm khách thành công, in thất bại. Hãy kiểm tra cài đặt máy in"; // ✅ in lỗi
      }
    } else {
      debugPrint('⚠️ Không tìm thấy máy in cho shop hiện tại, bỏ qua in');
      return "Thêm khách thành công, bạn có thể in đơn nếu cài đặt máy in trong cài đặt"; // ✅ không có máy in
    }

    // Sau này bạn có thể bổ sung tạo đơn hàng vào đây nếu cần
  }


}
