// lib/screens/owner/setting_printer.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/owner_services/printer_service.dart';

class SettingPrinterScreen extends StatefulWidget {
  final DocumentSnapshot? printerDoc;
  const SettingPrinterScreen({super.key, this.printerDoc});

  @override
  State<SettingPrinterScreen> createState() => _SettingPrinterScreenState();
}

class _SettingPrinterScreenState extends State<SettingPrinterScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _ipController;
  late TextEditingController _portController;

  late PrinterService printerService;
  final user = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    printerService = PrinterService(user.uid);

    _nameController = TextEditingController(text: widget.printerDoc?['name_printer'] ?? '');
    _ipController = TextEditingController(text: widget.printerDoc?['IP'] ?? '');
    _portController = TextEditingController(text: (widget.printerDoc?['Port']?.toString()) ?? '9100');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _savePrinter() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;

    try {
      if (widget.printerDoc == null) {
        await printerService.addPrinter(
          namePrinter: name,
          ip: ip,
          port: port,
        );
      } else {
        await printerService.updatePrinter(
          id: widget.printerDoc!.id,
          namePrinter: name,
          ip: ip,
          port: port,
        );
      }
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.printerDoc != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Chỉnh sửa máy in' : 'Thêm máy in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Đặt tên cho máy in'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên máy in' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(labelText: 'IP máy in'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập IP máy in';
                  final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
                  if (!ipRegex.hasMatch(v.trim())) return 'IP không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port máy in'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập port';
                  final port = int.tryParse(v.trim());
                  if (port == null || port < 1 || port > 65535) return 'Port không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _savePrinter,
                child: const Text('Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
