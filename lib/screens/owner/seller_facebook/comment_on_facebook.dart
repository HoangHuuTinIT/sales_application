import 'dart:async';
import 'package:ban_hang/widgets/comment_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ban_hang/services/owner_services/facebook_live_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:ban_hang/widgets/quick_reply_sheet.dart';
// enum ReplyActionType { replyToComment, sendMessage }
class CommentOnFacebookScreen extends StatefulWidget {
  const CommentOnFacebookScreen({super.key});

  @override
  State<CommentOnFacebookScreen> createState() => _CommentOnFacebookScreenState();
}

class _CommentOnFacebookScreenState extends State<CommentOnFacebookScreen> {
  List<Map<String, dynamic>> comments = [];
  List<Map<String, dynamic>> filteredComments = [];
  bool isLoading = false;
  final currentUser = FirebaseAuth.instance.currentUser;
  String? livestreamId;
  String? accessToken;
  String searchKeyword = '';
  String? filteredUserId;
  late IO.Socket socket;

  // phân trang
  int currentPage = 1;
  final int commentsPerPage = 70;

  // quản lý trạng thái "đang tạo đơn" cho từng comment
  Set<String> creatingOrders = {};

  // Xóa toàn bộ nội dung của hàm này
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

// Thay thế hàm initState cũ bằng hàm này
  @override
  void initState() {
    super.initState();

    // Dùng Future.delayed để đảm bảo context đã sẵn sàng
    Future.delayed(Duration.zero, () {
      if (mounted) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        if (args != null) {
          livestreamId = args['livestreamId'];
          accessToken = args['accessToken'];
          if (livestreamId != null && accessToken != null) {
            _loadComments();
          }
        }
      }
    });

    _initSocket();
  }

  void _initSocket() {
    socket = IO.io(
      "https://socket-server-642296570221.asia-southeast1.run.app",
      IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );

    socket.connect();

    socket.onConnect((_) => print("✅ Connected to server"));

    socket.on("new_comment", (data) {
      print("💬 Received new comment: $data");
      setState(() {
        comments.insert(0, Map<String, dynamic>.from(data));
        _applyFilter();
      });
    });

    socket.onDisconnect((_) => print("❌ Disconnected"));
  }

  void _filterCommentsByUser(String userId, String userName) {
    setState(() {
      filteredUserId = userId;
      searchKeyword = '';
      _applyFilter();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đang hiển thị bình luận của $userName'),
        action: SnackBarAction(
          label: 'Xem tất cả',
          onPressed: () {
            setState(() {
              filteredUserId = null;
              _applyFilter();
            });
          },
        ),
      ),
    );
  }

  Future<void> _loadComments({bool showLoading = true}) async {
    if (showLoading) setState(() => isLoading = true);

    try {
      final result = await FacebookLiveService().loadComments(livestreamId!, accessToken!);

      // sort theo thời gian
      result.sort((a, b) {
        final timeA = DateTime.tryParse(a['created_time'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = DateTime.tryParse(b['created_time'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });

      setState(() {
        comments = result;
        filteredUserId = null;
        _applyFilter();
      });
    } catch (e) {
      debugPrint('Error loading comments: $e');
    } finally {
      if (showLoading) setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    List<Map<String, dynamic>> temp = comments;

    if (filteredUserId != null) {
      temp = temp.where((c) => c['from']?['id'] == filteredUserId).toList();
    }

    if (searchKeyword.trim().isNotEmpty) {
      final keyword = searchKeyword.toLowerCase();
      temp = temp.where((c) {
        final message = c['message']?.toString().toLowerCase() ?? '';
        final name = c['from']?['name']?.toString().toLowerCase() ?? '';
        return message.contains(keyword) || name.contains(keyword);
      }).toList();
    }

    setState(() {
      filteredComments = temp;
      currentPage = 1; // reset về trang đầu khi filter
    });
  }

  Future<void> _filterByPhoneNumbers() async {
    setState(() => isLoading = true);
    final filtered = await FacebookLiveService().filterCommentsWithPhoneNumbers(comments);
    setState(() {
      filteredComments = filtered;
      isLoading = false;
      currentPage = 1;
    });
  }

  String _formatVietnamTime(String utcTime) {
    try {
      final dtUtc = DateTime.parse(utcTime);
      final dtVN = dtUtc.toLocal().add(const Duration(hours: 0));
      return DateFormat('HH:mm dd/MM/yyyy').format(dtVN);
    } catch (_) {
      return utcTime;
    }
  }

  // phân trang
  List<Map<String, dynamic>> get _pagedComments {
    final start = (currentPage - 1) * commentsPerPage;
    final end = (start + commentsPerPage).clamp(0, filteredComments.length);
    return filteredComments.sublist(start, end);
  }

  int get _totalPages => (filteredComments.length / commentsPerPage).ceil();

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }
  void _showCustomerInfoSheet(BuildContext context, Map<String, dynamic> comment)
  {
    final from = comment['from'] ?? {};
    final fbid = from['id'] ?? '';
    final name = from['name'] ?? 'Ẩn danh';
    final avatarUrl = from['picture']?['data']?['url'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: FacebookLiveService().getFacebookCustomerInfo(fbid),
          builder: (context, snapshot) {
            final bool isCurrentlyHidden = comment['is_hidden'] ?? false;
            Widget infoWidget;
            // ... (Phần code hiển thị thông tin khách hàng giữ nguyên)
            if (snapshot.connectionState == ConnectionState.waiting) {
              infoWidget = const Center(child: CircularProgressIndicator());
            } else {
              final customerData = snapshot.data;
              if (customerData != null) {
                // Hiển thị đầy đủ thông tin
                infoWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(customerData['name'] ?? name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18))),
                        if (avatarUrl != null)
                          CircleAvatar(
                              backgroundImage: NetworkImage(avatarUrl)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(customerData['phone'] ?? 'Chưa có SĐT'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(
                                customerData['address'] ?? 'Chưa có địa chỉ')),
                      ],
                    ),
                  ],
                );
              } else {
                // Hiển thị thông tin cơ bản
                infoWidget = Row(
                  children: [
                    Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18))),
                    if (avatarUrl != null)
                      CircleAvatar(
                          backgroundImage: NetworkImage(avatarUrl)),
                  ],
                );
              }
            }
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                runSpacing: 20,
                children: [
                  infoWidget,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton.icon(
                          onPressed: () {
                            // Khi nhấn "Trả lời"
                            Navigator.pop(sheetContext); // Đóng sheet hiện tại
                            _showQuickReplySheet(
                              context,
                              comment: comment,
                              actionType: ReplyActionType.replyToComment,
                            );
                          },
                          icon: const Icon(Icons.reply),
                          label: const Text("Trả lời")),
                      TextButton.icon(
                          onPressed: () {
                            // Khi nhấn "Gửi tin nhắn"
                            Navigator.pop(sheetContext); // Đóng sheet hiện tại
                            _showQuickReplySheet(
                              context,
                              comment: comment,
                              actionType: ReplyActionType.sendMessage,
                            );
                          },
                          icon: const Icon(Icons.send),
                          label: const Text("Gửi tin nhắn")),
                      if (isCurrentlyHidden)
                      // Nếu đang bị ẩn, hiển thị nút "Bỏ ẩn"
                        TextButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(sheetContext);
                            try {
                              await FacebookLiveService().setCommentHiddenState(
                                commentId: comment['id'],
                                accessToken: accessToken!,
                                isHidden: false, // <-- Bỏ ẩn
                              );
                              messenger.showSnackBar(const SnackBar(content: Text("Đã bỏ ẩn bình luận.")));
                              _loadComments(showLoading: false);
                            } catch (e) {
                              messenger.showSnackBar(SnackBar(content: Text("Lỗi: $e")));
                            }
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text("Bỏ ẩn"),
                        )
                      else
                      // Nếu đang hiển thị, hiển thị nút "Ẩn"
                        TextButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(sheetContext);
                            try {
                              await FacebookLiveService().setCommentHiddenState(
                                commentId: comment['id'],
                                accessToken: accessToken!,
                                isHidden: true, // <-- Ẩn
                              );
                              messenger.showSnackBar(const SnackBar(content: Text("Đã ẩn bình luận.")));
                              _loadComments(showLoading: false);
                            } catch (e) {
                              messenger.showSnackBar(SnackBar(content: Text("Lỗi: $e")));
                            }
                          },
                          icon: const Icon(Icons.visibility_off),
                          label: const Text("Ẩn"),
                        ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Bên trong hàm _showCustomerInfoSheet
// ...
                      TextButton.icon(
                        onPressed: () async {
                          // BƯỚC 1: Lấy tham chiếu đến ScaffoldMessenger và Context TRƯỚC
                          final messenger = ScaffoldMessenger.of(context);
                          final currentContext = context; // Có thể dùng trực tiếp context cũng được

                          // BƯỚC 2: Đóng bottom sheet
                          Navigator.pop(sheetContext);

                          try {
                            // BƯỚC 3: Gọi hàm service
                            await FacebookLiveService().makePhoneCall(fbid: fbid);
                          } catch (e) {
                            // BƯỚC 4: Dùng tham chiếu đã lấy để hiển thị thông báo.
                            // Cách này an toàn hơn vì không phải "tìm kiếm" lại context.
                            messenger.showSnackBar(
                              SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
                            );
                          }
                        },
                        icon: const Icon(Icons.call),
                        label: const Text("Gọi"),
                      ),
// ...
                      TextButton.icon(onPressed: (){}, icon: const Icon(Icons.comment), label: const Text("Bình luận")),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }


  void _showQuickReplySheet(
      BuildContext context, {
        required Map<String, dynamic> comment,
        required ReplyActionType actionType,
      })
  {
    final name = comment['from']?['name'] ?? 'Ẩn danh';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding:
        EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: QuickReplySheet(
          userName: name,
          comment: comment,
          actionType: actionType,
          accessToken: accessToken!, // Truyền accessToken vào
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bình luận livestream"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadComments()),
        ],
      ),
      body: Column(
        children: [
          // Header (Search và Filter)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên hoặc nội dung...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {
                searchKeyword = value;
                _applyFilter();
              }),
            ),
          ),
          // Phần danh sách comment được rút gọn
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredComments.isEmpty
                ? const Center(child: Text("Không có bình luận nào"))
                : ListView.builder(
              itemCount: _pagedComments.length,
              itemBuilder: (context, index) {
                final comment = _pagedComments[index];
                final userId = comment['from']?['id'] ?? '';
                return CommentItem( // <-- SỬ DỤNG WIDGET MỚI
                  comment: comment,
                  isCreatingOrder: creatingOrders.contains(userId),
                  formatTime: _formatVietnamTime,
                  onFilterByUser: _filterCommentsByUser,
                  onShowMoreOptions: () => _showCustomerInfoSheet(context, comment),
                  onCreateOrder: () async {
                    if (userId.isNotEmpty) {
                      setState(() => creatingOrders.add(userId));
                      try {
                        await FacebookLiveService().createOrderFromComment(
                          userId: userId,
                          name: comment['from']?['name'] ?? '',
                          time: _formatVietnamTime(comment['created_time'] ?? ''),
                          message: comment['message'] ?? '',
                        );
                        await _loadComments(showLoading: false);
                      } finally {
                        setState(() => creatingOrders.remove(userId));
                      }
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
// Thêm 2 phương thức này vào trong class _CommentOnFacebookScreenState


// Thêm Widget mới này vào cuối file comment_on_facebook.dart

