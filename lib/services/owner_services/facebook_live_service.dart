import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:phone_number/phone_number.dart';

class FacebookLiveService {

  final PhoneNumberUtil _phoneNumberUtil = PhoneNumberUtil();

  Future<List<Map<String, dynamic>>> getLivestreams(String pageId, String accessToken) async {
    final url = Uri.parse('https://graph.facebook.com/v19.0/$pageId/live_videos?access_token=$accessToken');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final liveVideos = data['data'] as List;
      return liveVideos.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception("Không thể lấy livestream");
    }
  }

  Future<List<Map<String, dynamic>>> getComments(String livestreamId, String accessToken) async {
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
  Future<List<Map<String, dynamic>>> filterCommentsWithPhoneNumbers(List<Map<String, dynamic>> comments) async {
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
        if (cleanedPhone.startsWith('0') && cleanedPhone.length >= 9 && cleanedPhone.length <= 10) {
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


}
