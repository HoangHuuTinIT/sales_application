import 'package:flutter/material.dart';
import 'package:ban_hang/services/manager_services/user_service.dart';

class UpdateAccountScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Function(Map<String, dynamic>) onSave;

  const UpdateAccountScreen({
    super.key,
    required this.userData,
    required this.onSave,
  });

  @override
  State<UpdateAccountScreen> createState() => _UpdateAccountScreenState();
}

class _UpdateAccountScreenState extends State<UpdateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  String? _selectedRoleDisplay; // 'Shipper', 'Nhân viên', 'Quản lý'

  final Map<String, String> _roleMapping = {
    'Shipper': 'delivery',
    'Nhân viên': 'staff',
    'Quản lý': 'manager',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name']);
    _emailController = TextEditingController(text: widget.userData['email']);
    _phoneController = TextEditingController(text: widget.userData['phone']);
    _addressController = TextEditingController(text: widget.userData['address']);

    // Xử lý role
    final currentRole = widget.userData['role'] ?? '';
    switch (currentRole) {
      case 'delivery':
        _selectedRoleDisplay = 'Shipper';
        break;
      case 'manager':
        _selectedRoleDisplay = 'Quản lý';
        break;
      case 'staff':
      default:
        _selectedRoleDisplay = 'Nhân viên';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final updatedData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'role': _roleMapping[_selectedRoleDisplay] ?? 'staff',
      };

      widget.onSave(updatedData);
      Navigator.pushNamed(context,'edit-accounts');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa tài khoản')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Họ tên'),
                validator: (value) => value!.isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => value!.isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                validator: (value) => value!.isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
                validator: (value) => value!.isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Vai trò'),
                value: _selectedRoleDisplay,
                onChanged: (value) {
                  setState(() {
                    _selectedRoleDisplay = value;
                  });
                },
                items: ['Shipper', 'Nhân viên', 'Quản lý']
                    .map((role) => DropdownMenuItem(
                  value: role,
                  child: Text(role),
                ))
                    .toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Chỉnh sửa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

