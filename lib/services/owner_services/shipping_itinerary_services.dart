// lib/services/owner_services/shipping_itinerary_services.dart
import 'dart:convert';

class ShippingItineraryServices {
  /// Parse response JSON từ J&T trace API
  static Map<String, dynamic>? parseTraceResponse(String? responseBody) {
    if (responseBody == null) return null;
    try {
      final data = jsonDecode(responseBody);
      if (data["code"] != "1") return null; // không thành công
      return data;
    } catch (e) {
      print("Error parseTraceResponse: $e");
      return null;
    }
  }
}
