import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data' as typed;
import 'package:barcode/barcode.dart';
import 'package:barcode_image/barcode_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:diacritic/diacritic.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

class BuyProductsService {
  final _ref = FirebaseFirestore.instance.collection('OrderedProducts');

  Future<void> createOrder({
    required String productId,
    required double total,
    required int quantity,
    required String paymentMethod,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Người dùng chưa đăng nhập');

    // Lấy thông tin user
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final name = userData?['name'] ?? '';
    final normalizedName = removeDiacritics(name).toLowerCase().trim();

    // ✅ Lấy shopid từ bảng Products
    final productDoc = await FirebaseFirestore.instance.collection('Products').doc(productId).get();
    if (!productDoc.exists) throw Exception('Không tìm thấy sản phẩm');
    final shopid = productDoc.data()?['shopid'];

    // Tạo đơn hàng
    final docRef = _ref.doc();
    await docRef.set({
      'orderedProductsId': docRef.id,
      'userId': user.uid,
      'productId': productId,
      'shopid': shopid, // ✅ Thêm shopId vào đơn hàng
      'total': total,
      'quantity': quantity,
      'paymentMethod': paymentMethod,
      'status': 'Đang chờ xác nhận',
      'createdAt': FieldValue.serverTimestamp(),
      'nameSearch': normalizedName,
    });
  }

  Future<Map<String, dynamic>?> fetchUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return snapshot.data();
  }

  Future<String> createOrderAndGetId({
    required String productId,
    required double total,
    required int quantity,
    required String paymentMethod,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Người dùng chưa đăng nhập');

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(
        user.uid).get();
    final userData = userDoc.data();
    final name = userData?['name'] ?? '';
    final normalizedName = removeDiacritics(name).toLowerCase().trim();
    final productDoc = await FirebaseFirestore.instance.collection('Products').doc(productId).get();
    if (!productDoc.exists) throw Exception('Không tìm thấy sản phẩm');
    final shopid = productDoc.data()?['shopid'];
    final docRef = _ref.doc();
    await docRef.set({
      'orderedProductsId': docRef.id,
      'userId': user.uid,
      'productId': productId,
      'total': total,
      'quantity': quantity,
      'shopid': shopid,
      'paymentMethod': paymentMethod,
      'status': 'Đang chờ xác nhận',
      'createdAt': FieldValue.serverTimestamp(),
      'nameSearch': normalizedName,
    });

    return docRef.id;
  }
  String generateOrderCode() {
    final now = DateTime.now();
    final datePart = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final timePart = "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
    final randomPart = (DateTime.now().microsecondsSinceEpoch % 10000)
        .toRadixString(36)
        .toUpperCase()
        .padLeft(4, '0');
    return "ODR-$datePart-$timePart-$randomPart";
  }

  Future<void> createOrders({
    required List<Map<String, dynamic>> selectedItems,
    required String paymentMethod,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Người dùng chưa đăng nhập');

    // Lấy thông tin user
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final name = (userData?['name'] ?? '').toString();
    final normalizedName = removeDiacritics(name).toLowerCase().trim();

    // Chuẩn hóa phương thức thanh toán
    final String pm = paymentMethod == 'Thanh toán khi nhận hàng' ? 'COD' : 'Stripe';

    // Làm giàu dữ liệu sản phẩm
    final List<Map<String, dynamic>> enriched = [];
    await Future.wait(selectedItems.map((item) async {
      final String productId = item['productId'];
      String? shopid = (item['shopid'] as String?);
      String? productName = (item['productName'] as String?);
      num? weight = (item['productWeight'] );
      num? stockQuantity = (item['productStockQuantity'] );
      num? price = (item['price'] as num?);

      if (shopid == null || productName == null || price == null) {
        final pDoc = await FirebaseFirestore.instance
            .collection('Products')
            .doc(productId)
            .get();
        if (!pDoc.exists) throw Exception('Không tìm thấy sản phẩm với ID: $productId');
        final p = pDoc.data()!;
        shopid ??= (p['shopid'] as String?) ?? '';
        productName ??= (p['productName'] as String?) ?? (p['name'] as String?) ?? '';
        price ??= (p['price'] as num?) ?? 0;
      }

      enriched.add({
        'productId': productId,
        'shopid': shopid,
        'productName': productName,
        'price': (price as num).toDouble(),
        'quantity': (item['quantity'] as num).toInt(),
        'totalAmount': (item['totalAmount'] != null)
            ? ((item['totalAmount'] as num).toDouble())
            : (price.toDouble() * (item['quantity'] as num).toDouble()),
        'weight':weight,
        'stockQuantity' : stockQuantity,
      });

    })
    );

    // Nhóm theo shopid
    final Map<String, List<Map<String, dynamic>>> itemsByShop = {};
    for (final it in enriched) {
      final sid = it['shopid'] as String;
      itemsByShop.putIfAbsent(sid, () => []);
      itemsByShop[sid]!.add(it);
    }

    // Tạo đơn hàng cho từng shop
    final ordersCol = FirebaseFirestore.instance.collection('OrderedProducts');

    for (final entry in itemsByShop.entries) {
      final String shopid = entry.key;
      final List<Map<String, dynamic>> items = entry.value;

      final double totalAmount = items.fold<double>(
        0.0,
            (sum, i) => sum + ((i['totalAmount'] as num).toDouble()),
      );

      // Tạo docRef trước
      final orderRef = ordersCol.doc();

      final Map<String, dynamic> orderData = {
        'orderedProductsId': orderRef.id,
        'orderCode': generateOrderCode(), // <-- Thêm mã đơn hàng
        'shopid': shopid,
        'userId': user.uid,
        'paymentMethod': pm,
        'status': 'Đang chờ xác nhận',
        'totalAmount': totalAmount,
        'createdAt': FieldValue.serverTimestamp(),
        'nameSearch': normalizedName,
      };

      final batch = FirebaseFirestore.instance.batch();
      batch.set(orderRef, orderData);

      // Thêm các OrderDetails
      final orderDetailsCol = orderRef.collection('OrderDetails');
      for (final i in items) {
        final detailRef = orderDetailsCol.doc();
        final num price = i['price'] as num;
        final int qty = i['quantity'] as int;

        batch.set(detailRef, {
          'productId': i['productId'],
          'productName': i['productName'],
          'stockQuantity':i['stockQuantity'],
          'weight' : i['weight'],
          'price': price.toDouble(),
          'quantity': qty,
          'total': (price.toDouble() * qty),
        });
      }

      await batch.commit();
    }
  }



}

