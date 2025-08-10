import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ApprovalAccountScreen extends StatefulWidget {
  const ApprovalAccountScreen({super.key});

  @override
  State<ApprovalAccountScreen> createState() => _ApprovalAccountScreenState();
}

class _ApprovalAccountScreenState extends State<ApprovalAccountScreen> {
  String filterRole = 'Tất cả';
  String filterStatus = 'Tất cả';
  DateTime? filterDate;

  Future<void> updateStatus(String userId, String status) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({'status': status});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý tài khoản'),
        backgroundColor: Colors.teal,
        centerTitle: true,
        elevation: 4,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButton<String>(
                            value: filterRole,
                            underline: const SizedBox(),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down),
                            items: ['Tất cả', 'staff', 'shipper']
                                .map((role) => DropdownMenuItem(
                              value: role,
                              child: Text('Vai trò: $role'),
                            ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  filterRole = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButton<String>(
                            value: filterStatus,
                            underline: const SizedBox(),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down),
                            items: ['Tất cả', 'chờ duyệt', 'đã duyệt', 'từ chối']
                                .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text('Trạng thái: $status'),
                            ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  filterStatus = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            filterDate = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(filterDate != null
                          ? 'Ngày: ${DateFormat('dd/MM/yyyy').format(filterDate!)}'
                          : 'Chọn ngày'),
                    ),
                    if (filterDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => filterDate = null),
                      ),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  if (!data.containsKey('role') || !data.containsKey('status')) return false;

                  final role = data['role'];
                  final status = data['status'];
                  final createdAt = data['createdAt']?.toDate();

                  final matchRole = filterRole == 'Tất cả' || role == filterRole;
                  final matchStatus = filterStatus == 'Tất cả' || status == filterStatus;
                  final matchDate = filterDate == null || (createdAt != null &&
                      createdAt.year == filterDate!.year &&
                      createdAt.month == filterDate!.month &&
                      createdAt.day == filterDate!.day);

                  return matchRole && matchStatus && matchDate;
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('Không có tài khoản nào phù hợp.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final user = docs[index];
                    final data = user.data() as Map<String, dynamic>;
                    final createdAt = data['createdAt']?.toDate();

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.grey.shade100,
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${data['name']} (${data['role']})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text('Email: ${data['email']}'),
                            Text('SĐT: ${data['phone']}'),
                            Text('Địa chỉ: ${data['address']}'),
                            if (createdAt != null)
                              Text('Ngày tạo: ${createdAt.day}/${createdAt.month}/${createdAt.year}'),
                            const SizedBox(height: 12),
                            if (data['status'] == 'chờ duyệt')
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FilledButton(
                                    onPressed: () async {
                                      await updateStatus(user.id, 'đã duyệt');
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    child: const Text('Xác nhận'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Xác nhận từ chối'),
                                          content: const Text('Bạn có chắc chắn muốn từ chối tài khoản này?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Hủy'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Từ chối'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await updateStatus(user.id, 'từ chối');
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                    child: const Text('Từ chối'),
                                  ),
                                ],
                              )
                          ],
                        ),
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
