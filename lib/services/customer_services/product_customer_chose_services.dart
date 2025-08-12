import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProductCustomerChoseService {
  final _productRef = FirebaseFirestore.instance.collection('Products');

  Future<Map<String, dynamic>?> getProductById(String id) async {
    try {
      final doc = await _productRef.doc(id).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'id': doc.id,
          ...data,
          'imageUrl': (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty)
              ? data['imageUrls'][0]
              : null,
          'discount': data['discount'] ?? 0,
          'discountEndDate': data['discountEndDate'],
        };
      }
      return null;
    } catch (e) {
      print('❌ Lỗi khi lấy sản phẩm: $e');
      return null;
    }
  }

  // Trong class ProductCustomerChoseService

  Future<void> submitRating({
    required String productId,
    required String userId,
    required int star,
    required String userName, // <-- THÊM
    required String userAvatar, // <-- THÊM
    String? comment,
    List<String>? imageUrls,
    List<String>? videoUrls,
  }) async {
    final bool hasMediaValue = (imageUrls?.isNotEmpty ?? false) || (videoUrls?.isNotEmpty ?? false);
    await FirebaseFirestore.instance.collection('customer_rate').add({
      'productId': productId,
      'userId': userId,
      'userName': userName, // <-- THÊM
      'userAvatar': userAvatar, // <-- THÊM
      'star': star,
      'comment': comment ?? '',
      'imageUrls': imageUrls ?? [],
      'videoUrls': videoUrls ?? [],
      'hasMedia': hasMediaValue, // <-- THÊM TRƯỜNG MỚI
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getRatingsByProduct({
    required String productId,
    int? star,
    bool? hasComment,
    bool? hasMedia,

  }) async {
    Query query = FirebaseFirestore.instance
        .collection('customer_rate')
        .where('productId', isEqualTo: productId);

    if (star != null) query = query.where('star', isEqualTo: star);
    if (hasComment == true) query = query.where('comment', isNotEqualTo: '');
    if (hasMedia == true) {
      // Truy vấn trên trường mới, rất nhanh và hiệu quả!
      query = query.where('hasMedia', isEqualTo: true);
    }
    final snapshot = await query.orderBy('createdAt', descending: true).get();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Không cần truy vấn thêm vào collection 'users' nữa
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final likedBy = List<String>.from(data['likedBy'] ?? []);

      return {
        'id': doc.id,
        ...data,
        // Dữ liệu đã có sẵn, chỉ cần lấy ra
        'userName': data['userName'] ?? 'Ẩn danh',
        'userAvatar': data['userAvatar'] ?? '',
        'like': data['like'] ?? 0,
        'isLikedByMe': currentUserId != null && likedBy.contains(currentUserId),
        'createdAt': (data['createdAt'] as Timestamp?)?.toDate().toString() ?? '',
      };
    }).toList();

  }

  /// ✅ Hàm mới: Upload nhiều file (ảnh/video) lên Firebase Storage
  /// và trả về danh sách URL
  Future<Map<String, List<String>>> uploadReviewMedia(List<XFile> files) async {
    final storage = FirebaseStorage.instance;
    List<String> imageUrls = [];
    List<String> videoUrls = [];

    for (final file in files) {
      final ext = file.path.split('.').last.toLowerCase();
      final isVideo = ext == 'mp4' || ext == 'mov' || ext == 'avi';

      final ref = storage
          .ref()
          .child('customer_rate/${DateTime.now().millisecondsSinceEpoch}_${file.name}');

      final uploadTask = await ref.putFile(File(file.path));
      final url = await uploadTask.ref.getDownloadURL();

      if (isVideo) {
        videoUrls.add(url);
      } else {
        imageUrls.add(url);
      }
    }

    return {
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,
    };
  }
  /// ✅ Hàm mới: Toggle like cho review
  Future<void> toggleLikeReview({
    required String reviewId,
    required String userId,
  }) async {
    final docRef = FirebaseFirestore.instance.collection('customer_rate').doc(reviewId);
    final docSnap = await docRef.get();
    final likedBy = List<String>.from(docSnap.data()?['likedBy'] ?? []);

    if (likedBy.contains(userId)) {
      likedBy.remove(userId);
      await docRef.update({
        'like': FieldValue.increment(-1),
        'likedBy': likedBy,
      });
    } else {
      likedBy.add(userId);
      await docRef.update({
        'like': FieldValue.increment(1),
        'likedBy': likedBy,
      });
    }
  }
  Future<void> deleteRating(String reviewId) async {
    await FirebaseFirestore.instance
        .collection('customer_rate')
        .doc(reviewId)
        .delete();
  }




}
