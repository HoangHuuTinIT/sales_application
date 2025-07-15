import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartItemsService {
  final _cartRef = FirebaseFirestore.instance.collection('CartItems');

  Future<void> addToCart({
    required String productId,
    required int quantity,
    required double totalAmount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Người dùng chưa đăng nhập');
    final existingCartItem = await _cartRef
        .where('userId', isEqualTo: user.uid)
        .where('productId', isEqualTo: productId)
        .limit(1)
        .get();

    if (existingCartItem.docs.isNotEmpty) {
      final doc = existingCartItem.docs.first;
      final currentQty = doc['quantity'] ?? 0;
      final currentTotal = doc['TotalAmount'] ?? 0.0;

      final newQty = currentQty + quantity;
      final newTotal = currentTotal + totalAmount;

      await _cartRef.doc(doc.id).update({
        'quantity': newQty,
        'TotalAmount': newTotal,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _cartRef.add({
        'userId': user.uid,
        'productId': productId,
        'quantity': quantity,
        'TotalAmount': totalAmount,
        'addedDate': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchCartItemsForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await _cartRef
        .where('userId', isEqualTo: user.uid)
        .orderBy('addedDate', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }
  Future<List<Map<String, dynamic>>> fetchCartItemsWithProductInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final cartSnapshot = await _cartRef
        .where('userId', isEqualTo: user.uid)
        .orderBy('addedDate', descending: true)
        .get();
    final List<Map<String, dynamic>> cartItems = [];
    for (final doc in cartSnapshot.docs) {
      final data = doc.data();
      final productId = data['productId'];

      // ✅ Tìm document theo doc ID
      final productDoc = await FirebaseFirestore.instance
          .collection('Products')
          .doc(productId)
          .get();

      if (productDoc.exists) {
        final productData = productDoc.data();
        cartItems.add({
          'productId': productId, // 👈 THÊM DÒNG NÀY để không bị null
          'productName': productData?['name'] ?? 'Không rõ tên',
          'productImage': productData?['imageUrls'] != null &&
              productData!['imageUrls'].isNotEmpty
              ? productData['imageUrls'][0]
              : null,
          'quantity': data['quantity'],
          'totalAmount': data['TotalAmount'],
        });

      } else {
        print("⚠️ Không tìm thấy sản phẩm với ID: $productId");
      }
    }

    return cartItems;
  }
  Future<void> deleteCartItemsByProductIds(List<String> productIds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await _cartRef
        .where('userId', isEqualTo: user.uid)
        .where('productId', whereIn: productIds)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }







}
