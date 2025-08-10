// lib/screens/owner/list_printer.dart
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

  void _showAddPrinter() {
    Navigator.pushNamed(context, '/setting-printer').then((_) {
      setState(() {}); // refresh sau khi thêm sửa
    });
  }

  void _showEditPrinter(DocumentSnapshot printerDoc) {
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
      appBar: AppBar(
        title: const Text('Danh sách máy in'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'add') _showAddPrinter();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'add', child: Text('Thêm máy in')),
            ],
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: printerService.streamPrinters(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Lỗi tải dữ liệu'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final printers = snapshot.data!.docs;
          if (printers.isEmpty) return const Center(child: Text('Chưa có máy in nào'));
          return ListView.builder(
            itemCount: printers.length,
            itemBuilder: (context, index) {
              final printerDoc = printers[index];
              final data = printerDoc.data() as Map<String, dynamic>;
              return ListTile(
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        data['name_printer'] ?? '(Không tên)',
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (data['default'] == true)
                      const SizedBox(width: 8),
                    if (data['default'] == true)
                      const Text(
                        '(Máy in mặc định)',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                subtitle: Text('IP: ${data['IP'] ?? ''}  - Port: ${data['Port'] ?? ''}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showEditPrinter(printerDoc);
                    } else if (value == 'delete') {
                      _deletePrinter(printerDoc);
                    } else if (value == 'set_default') {
                      await printerService.setDefaultPrinter(printerDoc.id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Máy "${data['name_printer']}" được đặt làm máy in mặc định')),
                      );
                      setState(() {});
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa máy in')),
                    const PopupMenuItem(value: 'delete', child: Text('Xóa máy in')),
                    const PopupMenuItem(value: 'set_default', child: Text('Đặt làm máy in mặc định')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
