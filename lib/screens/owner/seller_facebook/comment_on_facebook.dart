// import thêm
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ban_hang/services/owner_services/facebook_live_service.dart';

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
  Timer? autoRefreshTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    livestreamId = args?['livestreamId'];
    accessToken = args?['accessToken'];

    if (livestreamId != null && accessToken != null) {
      _loadComments();
      _startAutoRefresh();
    }
  }

  @override
  void dispose() {
    autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    autoRefreshTimer?.cancel();
    autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadComments());
  }

  Future<void> _loadComments({bool showLoading = true}) async {
    if (showLoading) setState(() => isLoading = true);

    try {
      final result = await FacebookLiveService().loadComments(livestreamId!, accessToken!);
      setState(() {
        comments = result;
        _applyFilter();
      });
    } catch (e) {
      debugPrint('Error loading comments: $e');
    } finally {
      if (showLoading) setState(() => isLoading = false);
    }
  }


  void _applyFilter() {
    setState(() {
      if (searchKeyword.trim().isEmpty) {
        filteredComments = comments;
      } else {
        filteredComments = comments.where((c) {
          final message = c['message']?.toString().toLowerCase() ?? '';
          final name = c['from']?['name']?.toString().toLowerCase() ?? '';
          final keyword = searchKeyword.toLowerCase();
          return message.contains(keyword) || name.contains(keyword);
        }).toList();
      }
    });
  }

  Future<void> _filterByPhoneNumbers() async {
    setState(() => isLoading = true);
    final filtered = await FacebookLiveService().filterCommentsWithPhoneNumbers(comments);
    setState(() {
      filteredComments = filtered;
      isLoading = false;
    });
  }

  String _formatVietnamTime(String utcTime) {
    try {
      final dtUtc = DateTime.parse(utcTime);
      final dtVN = dtUtc.toLocal().add(const Duration(hours: 7));
      return DateFormat('HH:mm dd/MM/yyyy').format(dtVN);
    } catch (_) {
      return utcTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bình luận livestream")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên hoặc nội dung...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                searchKeyword = value;
                _applyFilter();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _filterByPhoneNumbers,
                    icon: const Icon(Icons.phone),
                    label: const Text("Có số điện thoại"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        filteredComments = comments;
                      });
                    },
                    icon: const Icon(Icons.list),
                    label: const Text("Tất cả"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredComments.isEmpty
                ? const Center(child: Text("Không có bình luận nào"))
                : ListView.builder(
              itemCount: filteredComments.length,
              itemBuilder: (context, index) {
                final comment = filteredComments[index];
                final from = comment['from'];
                final avatarUrl = from?['picture']?['data']?['url'];
                final name = from?['name'] ?? '(Ẩn danh)';
                final message = comment['message'] ?? '';
                final time = _formatVietnamTime(comment['created_time'] ?? '');
                final status = comment['status'] ?? '';
                bool isCreating = false;
                return StatefulBuilder(
                  builder: (context, setState) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: avatarUrl != null
                                ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl), radius: 22)
                                : const CircleAvatar(child: Icon(Icons.person), radius: 22),
                          ),
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
                                  const SizedBox(height: 4),
                                  if (status == 'Bình thường')
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Text(
                                        'Bình thường',
                                        style: TextStyle(fontSize: 12, color: Colors.white ,),

                                      ),
                                    ),
                                  const SizedBox(height: 5),
                                  Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      height: 28,
                                      child: ElevatedButton(
                                        onPressed: isCreating
                                            ? null
                                            : () async {
                                          final userId = comment['from']?['id'];
                                          final name = comment['from']?['name'];
                                          final avatarUrl = comment['from']?['picture']?['data']?['url'];
                                          if (userId != null && name != null) {
                                            setState(() => isCreating = true);
                                            final facebookService = FacebookLiveService();

                                            try {
                                              await facebookService.createOrderFromComment(
                                                userId: userId,
                                                name: name,
                                                avatarUrl: avatarUrl,
                                                time: _formatVietnamTime(comment['created_time'] ?? ''),
                                                message: comment['message'] ?? '',
                                              );

                                              await _loadComments(showLoading: false);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("Tạo đơn thành công")),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('In thất bại. Hãy kiểm tra cài đặt máy in')),
                                                );
                                              }
                                            } finally {
                                              setState(() => isCreating = false);
                                            }
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                        ),
                                        child: isCreating
                                            ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                            : const Text("Tạo đơn", style: TextStyle(fontSize: 13)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
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