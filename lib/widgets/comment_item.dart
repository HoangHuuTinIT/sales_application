// lib/widgets/comment_item.dart
import 'package:flutter/material.dart';

class CommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool isCreatingOrder;
  final Function(String, String) onFilterByUser;
  final VoidCallback onCreateOrder;
  final VoidCallback onShowMoreOptions;
  final String Function(String) formatTime;

  const CommentItem({
    super.key,
    required this.comment,
    required this.isCreatingOrder,
    required this.onFilterByUser,
    required this.onCreateOrder,
    required this.onShowMoreOptions,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final from = comment['from'];
    final avatarUrl = from?['picture']?['data']?['url'];
    final name = from?['name'] ?? '(Ẩn danh)';
    final message = comment['message'] ?? '';
    final time = formatTime(comment['created_time'] ?? '');
    final userId = from?['id'] ?? '';
    final bool isHidden = comment['is_hidden'] ?? false;
    return Opacity(
      opacity: isHidden ? 0.5 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: avatarUrl != null
                  ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl), radius: 22)
                  : const CircleAvatar(child: Icon(Icons.person), radius: 22),
            ),
            // Comment Content
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        Text(time, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Nút tạo đơn
                        SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: isCreatingOrder ? null : onCreateOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            child: isCreatingOrder
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : const Text("Tạo đơn", style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Nút lọc bình luận
                        SizedBox(
                          height: 28,
                          child: OutlinedButton.icon(
                            onPressed: () => onFilterByUser(userId, name),
                            icon: const Icon(Icons.message, size: 16),
                            label: const Text('Bình luận khác', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const Spacer(), // Đẩy nút more sang phải
                        // Nút thêm
                        SizedBox(
                          height: 28,
                          width: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_horiz),
                            onPressed: onShowMoreOptions,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}