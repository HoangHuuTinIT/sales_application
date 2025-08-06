import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FacebookPageService {
  Future<List<Map<String, dynamic>>> getPages(String accessToken) async {
    final url = Uri.parse('https://graph.facebook.com/v23.0/me/accounts?access_token=$accessToken');
    final res = await http.get(url);
    print("===> Calling API: $url");
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      print("===> Facebook getPages raw data: ${res.body}");
      final pages = data['data'] as List;
      for (final p in pages) {
        print("Page: ${p['name']} - AccessToken: ${p['access_token']}");
      }

      return pages.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      print("Lỗi khi gọi API getPages: ${res.body}");
      throw Exception("Không thể lấy danh sách fanpage: ${res.body}");
    }

  }

  Future<void> savePageToFirestore({
    required String fbUserId,
    required Map<String, dynamic> pageData,
    required String displayName,
  }) async {
    final docId = "${fbUserId}_${pageData['id']}";
    await FirebaseFirestore.instance.collection('page_facebook_live').doc(docId).set({
      'fbUserId': fbUserId,
      'pageId': pageData['id'],
      'name': displayName,
      'accessToken': pageData['access_token'],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
