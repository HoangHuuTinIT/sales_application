import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ShippingCompanyService {
  static Future<void> saveViettelPostSettings({
    required GlobalKey<FormState> formKey,
    required BuildContext context,
    required Map<String, TextEditingController> controllers,
    required Map<String, dynamic> dropdownValues,
    required Map<String, bool> switches,
  }) async {
    if (!formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Người dùng chưa đăng nhập");

    final bool applySenderAddress = switches['applySenderAddress'] ?? false;
    final String? fullAddress = applySenderAddress
        ? "${controllers['detailAddress']?.text ?? ''} - ${dropdownValues['ward'] ?? ''} - ${dropdownValues['district'] ?? ''} - ${dropdownValues['province'] ?? ''}"
        : null;

    final shippingData = {
      'partnerName': 'Viettel Post',
      'isActive': switches['isActive'],
      'isDefaultTemplate': switches['isDefaultTemplate'],
      'senderName': _nullIfEmpty(controllers['senderName']),
      'senderPhone': _nullIfEmpty(controllers['senderPhone']),
      'account': controllers['account']?.text.trim(),
      'password': controllers['password']?.text.trim(),
      'service': dropdownValues['service'],
      'packageType': dropdownValues['packageType'],
      'paymentMethod': dropdownValues['paymentMethod'],
      'shippingNotes': dropdownValues['shippingNotes'],
      'postOffice': dropdownValues['postOffice'],
      'defaultFee': _nullIfEmpty(controllers['defaultFee']),
      'defaultWeight': _nullIfEmpty(controllers['defaultWeight']),
      'length': _nullIfEmpty(controllers['length']),
      'width': _nullIfEmpty(controllers['width']),
      'height': _nullIfEmpty(controllers['height']),
      'insuranceTotalValue': _nullIfEmpty(controllers['insuranceTotalValue']),
      'manualInsuranceValue': _nullIfEmpty(controllers['manualInsuranceValue']),
      'applySenderAddress': applySenderAddress,
      'senderAddress': fullAddress,
    };

    await FirebaseFirestore.instance
        .collection('ShippingCompany')
        .doc(uid)
        .set(shippingData, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lưu cấu hình thành công')),
      );
    }
  }

  static String? _nullIfEmpty(TextEditingController? controller) {
    final text = controller?.text.trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
