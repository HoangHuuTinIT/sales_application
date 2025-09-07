// lib/widgets/quick_reply_sheet.dart
import 'dart:async';
import 'package:ban_hang/services/owner_services/facebook_live_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Đặt enum ở đây để có thể dùng chung
enum ReplyActionType { replyToComment, sendMessage }

class QuickReplySheet extends StatefulWidget {
  final String userName;
  final Map<String, dynamic> comment;
  final ReplyActionType actionType;
  final String accessToken;

  const QuickReplySheet({
    super.key,
    required this.userName,
    required this.comment,
    required this.actionType,
    required this.accessToken,
  });

  @override
  State<QuickReplySheet> createState() => _QuickReplySheetState();
}

class _QuickReplySheetState extends State<QuickReplySheet> {
  final _messageController = TextEditingController();
  final _service = FacebookLiveService();
  bool _isSending = false;

  Future<void> _handleSend() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      if (widget.actionType == ReplyActionType.replyToComment) {
        final commentId = widget.comment['id'];
        await _service.replyToComment(
          commentId: commentId,
          message: message,
          accessToken: widget.accessToken,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Trả lời bình luận thành công! ✅")),
          );
        }
      } else if (widget.actionType == ReplyActionType.sendMessage) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Chức năng gửi tin nhắn đang được phát triển.")),
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.actionType == ReplyActionType.replyToComment
        ? "Đang trả lời bình luận"
        : "Đang gửi tin nhắn cho";

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
                Expanded(
                  child: Text(
                    "$title \"${widget.userName}\"",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 48), // Spacer
              ],
            ),
            const Divider(),
            // Danh sách tin nhắn nhanh
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _service.getQuickRepliesStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final replies = snapshot.data!.docs;
                  if (replies.isEmpty) {
                    return const Center(child: Text("Chưa có tin nhắn mẫu nào."));
                  }
                  return ListView.builder(
                    itemCount: replies.length,
                    itemBuilder: (context, index) {
                      final data = replies[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['title'] ?? '',
                            style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(data['message'] ?? ''),
                        onTap: () => setState(() {
                          _messageController.text = data['message'] ?? '';
                        }),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            // Vùng nhập liệu
            Row(
              children: [
                // IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: (){}),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: 5,
                    minLines: 1,
                    decoration: const InputDecoration(hintText: "Nhập nội dung..."),
                  ),
                ),
                _isSending
                    ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator()),
                )
                    : IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _handleSend,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}