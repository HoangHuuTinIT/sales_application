// File: lib/screens/manager/create_staff_account.dart
import 'package:ban_hang/services/auth_services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:vietnam_provinces/vietnam_provinces.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateStaffAccountScreen extends StatefulWidget {
  const CreateStaffAccountScreen({super.key});

  @override
  State<CreateStaffAccountScreen> createState() => _CreateStaffAccountScreenState();
}

class _CreateStaffAccountScreenState extends State<CreateStaffAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _detailAddressController = TextEditingController();
  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedWard;
  String _selectedRole = 'staff';
  bool _isSaving = false;
  int? _selectedProvinceCode;

  late AuthService _authService;
  List<Province> _provinces = [];
  List<District> _districts = [];
  List<Ward> _wards = [];

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _initLocationData();
  }

  Future<void> _initLocationData() async {
    await _authService.initLocations();
    setState(() {
      _provinces = _authService.getProvinces();
    });
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _phoneController.clear();
    _detailAddressController.clear();
    setState(() {
      _selectedRole = 'staff';
      _selectedProvince = null;
      _selectedDistrict = null;
      _selectedWard = null;
      _selectedProvinceCode = null;
      _districts = [];
      _wards = [];
    });
  }

  void _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null || _selectedDistrict == null || _selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng chọn đầy đủ địa chỉ")));
      return;
    }

    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    final fullAddress = "${_detailAddressController.text} - $_selectedWard - $_selectedDistrict - $_selectedProvince";

    final error = await _authService.createStaffAndDeliveryAccount(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      phone: _phoneController.text.trim(),
      address: fullAddress,
      role: _selectedRole,
      creatorId: user?.uid ?? "unknown",
    );

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo tài khoản thành công')));
      _resetForm();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: \$error')));
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cấp tài khoản')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Họ tên'),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập họ tên' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập email' : null,
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
                validator: (value) => value!.length < 6 ? 'Ít nhất 6 ký tự' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập số điện thoại' : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('Nhân viên')),
                  DropdownMenuItem(value: 'delivery', child: Text('Shipper')),
                ],
                onChanged: (val) => setState(() => _selectedRole = val!),
                decoration: const InputDecoration(labelText: 'Vai trò'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _detailAddressController,
                decoration: const InputDecoration(labelText: 'Địa chỉ chi tiết'),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập địa chỉ chi tiết' : null,
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Tỉnh/Thành phố'),
                value: _selectedProvince,
                hint: const Text('Chọn tỉnh/thành phố'),
                items: _provinces.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))).toList(),
                onChanged: (val) {
                  final selected = _provinces.firstWhere((p) => p.name == val);
                  setState(() {
                    _selectedProvince = val;
                    _selectedProvinceCode = selected.code;
                    _districts = _authService.getDistricts(selected.code);
                    _selectedDistrict = null;
                    _wards = [];
                  });
                },
              ),
              if (_districts.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Quận/Huyện'),
                  value: _selectedDistrict,
                  hint: const Text('Chọn quận/huyện'),
                  items: _districts.map((d) => DropdownMenuItem(value: d.name, child: Text(d.name))).toList(),
                  onChanged: (val) {
                    final selected = _districts.firstWhere((d) => d.name == val);
                    setState(() {
                      _selectedDistrict = val;
                      _wards = _authService.getWards(_selectedProvinceCode!, selected.code);
                      _selectedWard = null;
                    });
                  },
                ),
              if (_wards.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Phường/Xã'),
                  value: _selectedWard,
                  hint: const Text('Chọn phường/xã'),
                  items: _wards.map((w) => DropdownMenuItem(value: w.name, child: Text(w.name))).toList(),
                  onChanged: (val) => setState(() => _selectedWard = val),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _createAccount,
                icon: const Icon(Icons.person_add),
                label: _isSaving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Cấp tài khoản nhân viên và shipper'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
