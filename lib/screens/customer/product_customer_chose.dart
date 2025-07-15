import 'dart:io';
import 'package:ban_hang/screens/customer/buy_products.dart';
import 'package:ban_hang/screens/customer/cartitems_screen.dart';
import 'package:ban_hang/services/customer_services/product_customer_chose_services.dart';
import 'package:ban_hang/services/customer_services/cartitems_services.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class ProductCustomerChoseScreen extends StatefulWidget {
  final String productId;
  const ProductCustomerChoseScreen({super.key, required this.productId});

  @override
  State<ProductCustomerChoseScreen> createState() =>
      _ProductCustomerChoseScreenState();
}

class _ProductCustomerChoseScreenState extends State<ProductCustomerChoseScreen> {
  Map<String, dynamic>? product;
  bool isLoading = true;
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoPlayerFuture;
  int _selectedStar = 0;
  String _comment = '';
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedMedia = [];
  bool _isSubmitting = false;
  XFile? _expandedMedia; // media nào đang phóng to
  Set<String> _likedReviews = {}; // id các review đã like
  List<Map<String, dynamic>> _ratings = [];

// Bộ lọc
  int? _filterStar;
  bool _filterHasComment = false;
  bool _filterHasMedia = false;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProduct();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['action'] == 'showAddToCartDialog') {
        _showAddToCartDialog();
      }
    });
  }
  void _clearReviewInput() {
    setState(() {
      _selectedStar = 0;
      _comment = '';
      _selectedMedia.clear();
      _isSubmitting = false;
    });
  }

  void _loadProduct() async {
    final data = await ProductCustomerChoseService().getProductById(widget.productId);
    if (data?['videoUrl'] != null && data!['videoUrl'].toString().isNotEmpty) {
      _videoController = VideoPlayerController.network(data['videoUrl']);
      _initializeVideoPlayerFuture = _videoController!.initialize().then((_) {
        setState(() {});
      });
    }
    setState(() {
      product = data;
      isLoading = false;
    });
  }
  void _showAddReviewDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Đánh giá sản phẩm'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text('Chọn số sao:'),
                    StarRating(
                      rating: _selectedStar,
                      onRatingChanged: (star) {
                        setStateDialog(() {
                          _selectedStar = star;
                        });
                      },
                    ),
                    TextField(
                      decoration: const InputDecoration(hintText: 'Nhận xét (tuỳ chọn)'),
                      onChanged: (v) => _comment = v,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.photo),
                            label: const Text('Chọn 1 ảnh'),
                            onPressed: () async {
                              final List<XFile> images = await _picker.pickMultiImage();
                              if (images.isNotEmpty) {
                                setStateDialog(() {
                                  // chỉ giữ 1 ảnh đầu tiên, và xoá ảnh cũ
                                  _selectedMedia.removeWhere((file) =>
                                  !file.path.endsWith('.mp4') &&
                                      !file.path.endsWith('.mov') &&
                                      !file.path.endsWith('.avi'));
                                  _selectedMedia.add(images.first);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.videocam),
                            label: const Text('Chọn 1 video (≤10s)'),
                            onPressed: () async {
                              final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
                              if (video != null) {
                                final controller = VideoPlayerController.file(File(video.path));
                                await controller.initialize();
                                final duration = controller.value.duration;
                                controller.dispose();

                                if (duration.inSeconds > 10) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('❌ Video phải ngắn hơn 10 giây')),
                                  );
                                  return;
                                }

                                setStateDialog(() {
                                  // Xoá video cũ (nếu có)
                                  _selectedMedia.removeWhere((file) =>
                                  file.path.endsWith('.mp4') ||
                                      file.path.endsWith('.mov') ||
                                      file.path.endsWith('.avi'));
                                  _selectedMedia.add(video);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedMedia.map((file) {
                        final bool isExpanded = _expandedMedia == file;
                        final bool isVideo = file.path.endsWith('.mp4') || file.path.endsWith('.mov') || file.path.endsWith('.avi');

                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              _expandedMedia = isExpanded ? null : file;
                            });
                          },
                          child: Container(
                            width: isExpanded ? 150 : 80,
                            height: isExpanded ? 150 : 80,
                            color: Colors.black12,
                            child: isVideo
                                ? const Icon(Icons.videocam)
                                : Image.file(File(file.path), fit: BoxFit.cover),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _clearReviewInput();
                    Navigator.pop(context);
                  },
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : () async {
                    if (_selectedStar == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng chọn số sao')),
                      );
                      return;
                    }

                    // ✅ Check lại video nếu có, không cho đăng nếu >10s
                    for (final file in _selectedMedia) {
                      final ext = file.path.split('.').last.toLowerCase();
                      final isVideo = ext == 'mp4' || ext == 'mov' || ext == 'avi';

                      if (isVideo) {
                        final controller = VideoPlayerController.file(File(file.path));
                        await controller.initialize();
                        final duration = controller.value.duration;
                        controller.dispose();

                        if (duration.inSeconds > 10) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('❌ Video phải dưới 10 giây')),
                          );
                          return;
                        }
                      }
                    }

                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    setStateDialog(() {
                      _isSubmitting = true;
                    });

                    Map<String, List<String>> mediaUrls = {'imageUrls': [], 'videoUrls': []};
                    if (_selectedMedia.isNotEmpty) {
                      mediaUrls = await ProductCustomerChoseService().uploadReviewMedia(_selectedMedia);
                    }

                    await ProductCustomerChoseService().submitRating(
                      productId: widget.productId,
                      userId: user.uid,
                      star: _selectedStar,
                      comment: _comment,
                      imageUrls: mediaUrls['imageUrls'],
                      videoUrls: mediaUrls['videoUrls'],
                    );

                    setStateDialog(() {
                      _isSubmitting = false;
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Đã gửi đánh giá')),
                    );
                    setState(() {});
                  },
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Đăng'),
                ),
              ],
            );
          },
        );
      },
    );

  }

  void _showAddToCartDialog() {
    final DateTime now = DateTime.now();
    final double discount = (product!['discount'] ?? 0).toDouble();
    final DateTime? discountEndDate = product!['discountEndDate']?.toDate();
    final bool hasDiscount = discount > 0 && (discountEndDate == null || discountEndDate.isAfter(now));

    double price = (product!['price'] as num).toDouble();
    if (hasDiscount) {
      price = price * (1 - discount / 100);
    }
    int stockQuantity = product!['stockQuantity'] ?? 0;

    showDialog(
      context: context,
      builder: (context) =>
          _buildAddToCartDialog(context, price, stockQuantity),
    );
  }

  Future<void> _addToCart(int quantity, double totalAmount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Người dùng chưa đăng nhập');

      final productId = widget.productId;

      await CartItemsService().addToCart(
        productId: productId,
        quantity: quantity,
        totalAmount: totalAmount,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Đã thêm vào giỏ hàng')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi: $e')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final double discount = (product?['discount'] ?? 0).toDouble();
    final DateTime? discountEndDate = product?['discountEndDate']?.toDate();
    final bool hasDiscount = discount > 0 && (discountEndDate == null || discountEndDate.isAfter(now));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => CartItemsScreen()));
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : product == null
          ? const Center(child: Text('Không tìm thấy sản phẩm'))
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ẢNH + VIDEO
            ImageSlideshow(
              width: double.infinity,
              height: 250,
              initialPage: 0,
              indicatorColor: Colors.deepOrange,
              indicatorBackgroundColor: Colors.grey,
              children: [
                if (_videoController != null && _videoController!.value.isInitialized)
                  AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_videoController!),
                        IconButton(
                          icon: Icon(
                            _videoController!.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            size: 64,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_videoController!.value.isPlaying) {
                                _videoController!.pause();
                              } else {
                                _videoController!.play();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ...(product!['imageUrls'] as List<dynamic>).isNotEmpty
                    ? (product!['imageUrls'] as List<dynamic>).map((url) {
                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset('assets/images/background_no_image.png'),
                  );
                }).toList()
                    : [Image.asset('assets/images/background_no_image.png')],
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // GIÁ + ĐÃ BÁN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasDiscount)
                            Text(
                              message.formatCurrency(product!['price']),
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          Text(
                            message.formatCurrency(
                              hasDiscount ? (product!['price'] * (1 - discount / 100)) : product!['price'],
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      Text('Đã bán: ${product!['sold'] ?? 0}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(product!['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  const Text('Mô tả sản phẩm', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(product!['description'] ?? 'Không có mô tả'),

                  // NÚT ĐÁNH GIÁ
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showAddReviewDialog,
                        icon: const Icon(Icons.rate_review),
                        label: const Text('Viết đánh giá'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),

                  // FILTER
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        DropdownButton<int?>(
                          value: _filterStar,
                          hint: const Text('Sao'),
                          items: [null, 1, 2, 3, 4, 5].map((star) {
                            return DropdownMenuItem<int?>(
                              value: star,
                              child: Text(star == null ? 'Tất cả' : '$star ⭐'),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _filterStar = v),
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: _filterHasComment,
                              onChanged: (v) => setState(() => _filterHasComment = v!),
                            ),
                            const Text('Có nhận xét'),
                          ],
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: _filterHasMedia,
                              onChanged: (v) => setState(() => _filterHasMedia = v!),
                            ),
                            const Text('Có ảnh/video'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // REVIEWS
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: ProductCustomerChoseService().getRatingsByProduct(
                      productId: widget.productId,
                      star: _filterStar,
                      hasComment: _filterHasComment,
                      hasMedia: _filterHasMedia,
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final reviews = snapshot.data!;
                      _likedReviews = reviews
                          .where((r) => r['isLikedByMe'] == true)
                          .map((r) => r['id'] as String)
                          .toSet();

                      return Column(
                        children: reviews.map((review) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundImage: NetworkImage(review['userAvatar'] ?? ''),
                                        radius: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              review['userName'] ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            Row(
                                              children: List.generate(5, (index) {
                                                return Icon(
                                                  Icons.star,
                                                  color: index < review['star'] ? Colors.amber : Colors.grey,
                                                  size: 16,
                                                );
                                              }),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              _likedReviews.contains(review['id'])
                                                  ? Icons.thumb_up
                                                  : Icons.thumb_up_alt_outlined,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () async {
                                              final userId = FirebaseAuth.instance.currentUser?.uid;
                                              if (userId == null) return;

                                              await ProductCustomerChoseService().toggleLikeReview(
                                                reviewId: review['id'],
                                                userId: userId,
                                              );

                                              setState(() {
                                                if (_likedReviews.contains(review['id'])) {
                                                  _likedReviews.remove(review['id']);
                                                } else {
                                                  _likedReviews.add(review['id']);
                                                }
                                              });

                                              final doc = await FirebaseFirestore.instance
                                                  .collection('customer_rate')
                                                  .doc(review['id'])
                                                  .get();
                                              setState(() {
                                                review['like'] = doc.data()?['like'] ?? 0;
                                              });
                                            },
                                          ),
                                          Text('${review['like'] ?? 0}'),

                                          // ✅ Thêm nút xoá nếu đúng owner
                                          if (review['userId'] == FirebaseAuth.instance.currentUser?.uid)
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text("Xoá đánh giá"),
                                                    content: const Text("Bạn có chắc chắn muốn xoá không?"),
                                                    actions: [
                                                      TextButton(
                                                        child: const Text("Huỷ"),
                                                        onPressed: () => Navigator.pop(context, false),
                                                      ),
                                                      ElevatedButton(
                                                        child: const Text("Xoá"),
                                                        onPressed: () => Navigator.pop(context, true),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirm == true) {
                                                  await ProductCustomerChoseService().deleteRating(review['id']);
                                                  setState(() {
                                                    _ratings.removeWhere((r) => r['id'] == review['id']);
                                                  });
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if ((review['comment'] ?? '').isNotEmpty)
                                    Text(review['comment'], style: const TextStyle(fontSize: 15)),
                                  const SizedBox(height: 8),
                                  if ((review['imageUrls'] as List).isNotEmpty)
                                    GridView.count(
                                      crossAxisCount: 3,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: 6,
                                      mainAxisSpacing: 6,
                                      children: (review['imageUrls'] as List<dynamic>).map<Widget>((url) {
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(url, fit: BoxFit.cover),
                                        );
                                      }).toList(),
                                    ),
                                  if ((review['videoUrls'] as List).isNotEmpty)
                                    GridView.count(
                                      crossAxisCount: 1,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      children: (review['videoUrls'] as List<dynamic>).map<Widget>((url) {
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: SizedBox(
                                            height: 200,
                                            child: VideoPlayerWidget(videoUrl: url),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  const SizedBox(height: 6),
                                  Text('Ngày: ${review['createdAt'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'payment_fab',
            onPressed: () {
              final price = (product!['price'] as num).toDouble();
              final finalPrice = hasDiscount ? price * (1 - discount / 100) : price;

              message.checkSignInOrNot(
                context: context,
                onLoggedIn: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BuyProductsScreen(
                        selectedItems: [
                          {
                            'productId': product!['productId'],
                            'productName': product!['name'],
                            'productImage': (product!['imageUrls'] as List).isNotEmpty
                                ? product!['imageUrls'][0]
                                : null,
                            'quantity': 1,
                            'totalAmount': finalPrice,
                          }
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            label: const Text('Mua ngay'),
            icon: const Icon(Icons.payment),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'cart_fab',
            onPressed: () {
              message.checkSignInOrNot(
                context: context,
                onLoggedIn: _showAddToCartDialog,
                redirectRoute: '/product_detail',
                arguments: {
                  'productId': widget.productId,
                  'action': 'showAddToCartDialog',
                },
              );
            },
            child: const Icon(Icons.shopping_cart),
          ),
        ],
      ),
    );
  }


  Widget _buildAddToCartDialog(BuildContext context, double price, int stockQuantity) {
    int quantity = 1;
    final controller = TextEditingController(text: '1');
    double totalPrice = quantity * price;
    String? quantityError;
    return StatefulBuilder(
      builder: (context, setStateDialog) {
        return AlertDialog(
          title: const Text('Thêm vào giỏ hàng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product?['imageUrls'] != null &&
                  (product!['imageUrls'] as List).isNotEmpty)
                Image.network(product!['imageUrls'][0], height: 100),
              const SizedBox(height: 10),
              Text('Giá: ${message.formatCurrency(price)}'),
              Text('Tồn kho: $stockQuantity'),
              Text('Tổng tiền: ${message.formatCurrency(totalPrice)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      if (quantity > 1) {
                        quantity--;
                        controller.text = quantity.toString();
                        totalPrice = quantity * price;
                        quantityError = null;
                        setStateDialog(() {});
                      }
                    },
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed == null || parsed <= 0) {
                          quantityError = 'Nhập số lượng hợp lệ';
                        } else {
                          quantity = parsed;
                          totalPrice = quantity * price;
                          quantityError = null;
                        }
                        setStateDialog(() {});
                      },
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      quantity++;
                      controller.text = quantity.toString();
                      totalPrice = quantity * price;
                      quantityError = null;
                      setStateDialog(() {});
                    },
                  ),
                ],
              ),
              if (quantityError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    quantityError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: quantityError != null
                  ? null
                  : () async {
                await _addToCart(quantity, totalPrice);
                Navigator.pop(context);
              },
              child: const Text('Thêm vào giỏ hàng'),
            ),


          ],
        );
      },
    );
  }
}
class StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRatingChanged;

  const StarRating({super.key, required this.rating, required this.onRatingChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return IconButton(
          icon: Icon(
            Icons.star,
            color: starIndex <= rating ? Colors.amber : Colors.grey,
          ),
          onPressed: () => onRatingChanged(starIndex),
        );
      }),
    );
  }
}


class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        IconButton(
          icon: Icon(
            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 40,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              if (_controller.value.isPlaying) {
                _controller.pause();
              } else {
                _controller.play();
              }
            });
          },
        ),
      ],
    );
  }
}



