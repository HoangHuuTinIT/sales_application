import 'dart:convert';
import 'package:flutter/services.dart';

class AddressUtils {
  static Map<String, dynamic> _addressData = {};

  /// Load JSON từ assets (chỉ gọi 1 lần)
  static Future<void> loadAddressJson() async {
    if (_addressData.isNotEmpty) return; // đã load
    final response =
    await rootBundle.loadString('assets/json/mapping_J&T_address.json');
    _addressData = json.decode(response) as Map<String, dynamic>;
  }

  /// Lấy danh sách tỉnh/thành phố
  static List<String> getProvinces() {
    return _addressData.keys.toList();
  }

  /// Lấy danh sách quận/huyện theo tỉnh
  static List<String> getDistricts(String province) {
    if (!_addressData.containsKey(province)) return [];
    final districts = _addressData[province] as Map<String, dynamic>;
    return districts.keys.toList();
  }

  /// Lấy danh sách phường theo tỉnh và quận
  /// Giá trị trả về là "Tên Phường-Mã"
  static List<String> getWards(String province, String district) {
    if (!_addressData.containsKey(province)) return [];
    final districts = _addressData[province] as Map<String, dynamic>;
    if (!districts.containsKey(district)) return [];
    final wards = districts[district] as List;
    return wards.map((e) => e.toString()).toList();
  }


  /// Tách địa chỉ đầy đủ thành chi tiết, phường, quận, tỉnh
  /// Trả về map với keys: addressDetail, ward, district, province
  static Map<String, String?> parseFullAddress(String fullAddress) {
    final parts = fullAddress.split(' - ');
    if (parts.length < 4) return {};
    return {
      'addressDetail': parts[0],
      'ward': parts[parts.length - 3],
      'district': parts[parts.length - 2],
      'province': parts[parts.length - 1],
    };
  }

  /// Build địa chỉ đầy đủ từ các thành phần
  static String buildFullAddress({
    required String addressDetail,
    required String ward,
    required String district,
    required String province,
  }) {
    return '$addressDetail - $ward - $district - $province';
  }

  /// Tìm phường theo tên (bỏ qua mã), trả về giá trị đầy đủ (có mã)
  /// Nếu không tìm thấy, trả về null
  static String? findWardByName(
      {required String province,
        required String district,
        required String wardName}) {
    final wards = getWards(province, district);
    return wards.firstWhere(
            (w) => w.split('-').first.trim() == wardName.trim(),
        orElse: () => '');
  }
}
