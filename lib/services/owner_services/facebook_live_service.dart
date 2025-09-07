
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:phone_number/phone_number.dart';
import 'package:url_launcher/url_launcher.dart';

class FacebookLiveService {

  final PhoneNumberUtil _phoneNumberUtil = PhoneNumberUtil();

  Future<List<Map<String, dynamic>>> getLivestreams(
      String pageId, String accessToken) async {
    final url = Uri.parse(
      'https://graph.facebook.com/v23.0/$pageId/live_videos'
          '?broadcast_status=["LIVE"]'
          '&fields=id,live_status,permalink_url,title,description'
          '&access_token=$accessToken',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final videos = data['data'] as List;
      return videos.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception('Error: ${response.body}');
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




  // Future<List<Map<String, dynamic>>> getComments(String livestreamId,
  //     String accessToken) async {
  //   final url = Uri.parse(
  //     'https://graph.facebook.com/v23.0/$livestreamId/comments?fields=from{name,picture{url}},message,created_time&access_token=$accessToken',
  //   );
  //   final res = await http.get(url);
  //   if (res.statusCode == 200) {
  //     final data = json.decode(res.body);
  //     final comments = data['data'] as List;
  //     return comments.map((c) => Map<String, dynamic>.from(c)).toList();
  //   } else {
  //     throw Exception("Không thể lấy comment");
  //   }
  // }


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
    // required String? avatarUrl,
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
        // 'avatarUrl': avatarUrl,
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


  Future<String> createOrderFromComment({
    required String userId,
    required String name,
    required String time,
    required String message,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('Chưa đăng nhập');

    // 1. Tạo customer record nếu chưa có
    await createCustomerRecordsIfNotExists(
      fbid: userId,
      name: name,
      creatorId: currentUserId,
    );

    // ❌ Bỏ toàn bộ logic máy in & in comment

    return "Thành công"; // ✅ chỉ báo đã thêm khách
  }

  Future<List<Map<String, dynamic>>> loadCommentsByUser ({
    required String livestreamId,
    required String accessToken,
    required String userId,
  }) async {
    final allComments = await loadComments(livestreamId, accessToken);
    final userComments = allComments.where((c) => c['from']?['id'] == userId).toList();
    return userComments;
  }
  // Thêm các hàm này vào cuối class FacebookLiveService

  // Hàm lấy shopId của người dùng hiện tại
  Future<String?> _getCurrentShopId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return userDoc.data()?['shopid'];
  }

  // Hàm kiểm tra và lấy thông tin khách hàng từ fbid
  Future<Map<String, dynamic>?> getFacebookCustomerInfo(String fbid) async {
    final shopId = await _getCurrentShopId();
    if (shopId == null) return null;

    final firestore = FirebaseFirestore.instance;

    // 1. Tìm khách hàng trong bảng 'facebook_customer' bằng fbid
    final customerQuery = await firestore
        .collection('facebook_customer')
        .where('fbid', isEqualTo: fbid)
        .limit(1)
        .get();

    if (customerQuery.docs.isEmpty) {
      return null; // Không tìm thấy khách hàng
    }

    // 2. Lấy DocumentReference của khách hàng vừa tìm được
    final customerDoc = customerQuery.docs.first;
    final customerRef = customerDoc.reference;

    // 3. Kiểm tra xem khách hàng này có thuộc shop hiện tại không
    final shopCustomerQuery = await firestore
        .collection('shop_facebook_customer')
        .where('customerRef', isEqualTo: customerRef)
        .where('shopid', isEqualTo: shopId)
        .limit(1)
        .get();

    if (shopCustomerQuery.docs.isNotEmpty) {
      // Nếu có, trả về dữ liệu của khách hàng đó
      return customerDoc.data();
    }

    return null; // Khách hàng không thuộc shop này
  }

  // Lấy danh sách tin nhắn nhanh theo shopId (dưới dạng Stream)
  Stream<QuerySnapshot> getQuickRepliesStream() async* {
    final shopId = await _getCurrentShopId();
    if (shopId != null) {
      yield* FirebaseFirestore.instance
          .collection('quick_reply')
          .where('shopid', isEqualTo: shopId)
          .snapshots();
    }
  }

  // Thêm tin nhắn nhanh mới
  Future<void> addQuickReply({required String title, required String message}) async {
    final shopId = await _getCurrentShopId();
    if (shopId == null) {
      throw Exception("Không tìm thấy shop của người dùng.");
    }
    if (title.isEmpty || message.isEmpty) {
      throw Exception("Tiêu đề và nội dung không được để trống.");
    }

    await FirebaseFirestore.instance.collection('quick_reply').add({
      'shopid': shopId,
      'title': title,
      'message': message,
    });
  }
  Future<void> replyToComment({
    required String commentId,
    required String message,
    required String accessToken,
  }) async {
    final url =
    Uri.parse('https://graph.facebook.com/v23.0/$commentId/comments');
    final response = await http.post(
      url,
      body: {
        'message': message,
        'access_token': accessToken,
      },
    );

    if (response.statusCode == 200) {
      print("Successfully replied to comment $commentId");
      // Trả về void vì thành công không cần giá trị trả về
    } else {
      print(
          "Failed to reply. Status: ${response.statusCode}, Body: ${response.body}");
      // Ném ra một Exception để UI có thể bắt và hiển thị lỗi
      throw Exception('Không thể gửi trả lời: ${response.body}');
    }
  }
  /// Kiểm tra và thực hiện cuộc gọi tới khách hàng qua fbid.
  Future<void> makePhoneCall({required String fbid}) async {
    // Tận dụng hàm đã có để lấy thông tin khách hàng
    final customerData = await getFacebookCustomerInfo(fbid);

    if (customerData != null) {
      // Kiểm tra xem khách hàng có trường 'phone' không
      final phoneNumber = customerData['phone'];

      if (phoneNumber != null && phoneNumber.toString().isNotEmpty) {
        final uri = Uri.parse('tel:$phoneNumber');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          throw Exception('Không thể thực hiện cuộc gọi tới số $phoneNumber');
        }
      } else {
        // Ném ra lỗi nếu không có SĐT
        throw Exception('Chưa có số điện thoại của khách hàng này');
      }
    } else {
      // Ném ra lỗi nếu không tìm thấy khách hàng
      throw Exception('Không tìm thấy thông tin khách hàng');
    }
  }
  Future<List<Map<String, dynamic>>> getComments(String livestreamId, String accessToken) async {
    // Thêm is_hidden vào danh sách các trường cần lấy
    final url = Uri.parse(
      'https://graph.facebook.com/v19.0/$livestreamId/comments?fields=from{name,picture{url}},message,created_time,is_hidden&access_token=$accessToken',
    );
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final comments = data['data'] as List;
      return comments.map((c) => Map<String, dynamic>.from(c)).toList();
    } else {
      throw Exception("Không thể lấy comment: ${res.body}");
    }
  }
  /// Ẩn hoặc bỏ ẩn một bình luận.
  /// Yêu cầu quyền 'pages_manage_engagement'.
  Future<void> setCommentHiddenState({
    required String commentId,
    required String accessToken,
    required bool isHidden, // true để ẩn, false để bỏ ẩn
  }) async {
    final url = Uri.parse('https://graph.facebook.com/v19.0/$commentId');

    final response = await http.post(
      url,
      body: {
        'is_hidden': isHidden.toString(), // Gửi 'true' hoặc 'false'
        'access_token': accessToken,
      },
    );

    if (response.statusCode == 200) {
      print("Successfully set hidden state to $isHidden for comment $commentId");
    } else {
      throw Exception('Failed to set hidden state: ${response.body}');
    }
  }
}
