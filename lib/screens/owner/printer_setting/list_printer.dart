import 'package:ban_hang/services/owner_services/printer_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ListPrinterScreen extends StatefulWidget {
  const ListPrinterScreen({super.key});

  @override
  State<ListPrinterScreen> createState() => _ListPrinterScreenState();
}

class _ListPrinterScreenState extends State<ListPrinterScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  late PrinterService printerService;

  @override
  void initState() {
    super.initState();
    printerService = PrinterService(user.uid);
  }

  void _showEditPrinter([DocumentSnapshot? printerDoc]) {
    Navigator.pushNamed(context, '/setting-printer', arguments: printerDoc).then((_) {
      setState(() {}); // refresh
    });
  }

  void _deletePrinter(DocumentSnapshot printerDoc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có muốn xóa máy in này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirm == true) {
      await printerService.deletePrinter(printerDoc.id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Máy in ESC/POS (In qua Wifi)')),
      body: StreamBuilder<QuerySnapshot>(
        stream: printerService.streamPrinters(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Lỗi tải dữ liệu'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final printers = snapshot.data!.docs;
          if (printers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Chưa cấu hình máy in"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showEditPrinter(),
                    child: const Text("Thêm máy in ESC/POS (Wi-Fi)"),
                  )
                ],
              ),
            );
          }

          final printerDoc = printers.first; // ✅ chỉ lấy 1 máy in cho shop
          final data = printerDoc.data() as Map<String, dynamic>;

          return ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Máy in ESC/POS (In qua Wifi)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditPrinter(printerDoc);
                    } else if (value == 'delete') {
                      _deletePrinter(printerDoc);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa máy in')),
                    const PopupMenuItem(value: 'delete', child: Text('Xóa máy in')),
                  ],
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tên: ${data['name'] ?? '(Không tên)'}"),
                Text("IP: ${data['IP'] ?? ''}  - Port: ${data['Port'] ?? ''}"),
                if ((data['note'] ?? '').toString().trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      'Ghi chú: ${data['note']}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
