import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StripePaymentService {
  StripePaymentService() {
    Stripe.publishableKey = 'pk_test_51RpP09FYNYiKITZmveOBCkxir9ZYbkvoGbVbJ7uyxu6LzrpXChvjLPo9IZ6lyo4tbvwneqe7pX2YMNwz6DTvbaea005yov5ytq'; // Thay bằng publishable key của bạn
  }

  Future<bool> processPayment(double amount) async {
    try {
      final response = await http.post(
        Uri.parse('https://us-central1-sales-application-25165.cloudfunctions.net/createPaymentIntent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': (amount).toInt()}), // Stripe tính theo cent
      );
      print('>>> Trạng thái response: ${response.statusCode}');
      print('>>> Nội dung response: ${response.body}');
      if (response.statusCode != 200) {
        throw Exception('Tạo PaymentIntent thất bại');
      }
      final paymentIntent = jsonDecode(response.body);
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['clientSecret'],
          merchantDisplayName: 'Quân đoàn mua sắm',
          customerId: paymentIntent['customer'],
          customerEphemeralKeySecret: paymentIntent['ephemeralKey'],
          style: ThemeMode.light,
          allowsDelayedPaymentMethods: true,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return true;
    } catch (e) {
      print('❌ Lỗi thanh toán: $e');
      return false;
    }
  }

  Future<void> addOrderToFirestore({
    required Map<String, dynamic> item,
    required String paymentMethod,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Chưa đăng nhập");
    final docRef = FirebaseFirestore.instance.collection('OrderedProducts').doc();
    await docRef.set({
      'orderedProductsId': docRef.id,
      'userId': user.uid,
      'productId': item['productId'],
      'quantity': item['quantity'],
      'total': item['totalAmount'],
      'paymentMethod': paymentMethod,
      'status': 'Đang chờ xác nhận',
      'nameSearch': item['productName'].toString().toLowerCase(),
      'createdAt': Timestamp.now(),
    });
  }
}
