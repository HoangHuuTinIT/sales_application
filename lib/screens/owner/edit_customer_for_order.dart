import 'package:ban_hang/services/auth_services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:vietnam_provinces/vietnam_provinces.dart';

class EditCustomerForOrderScreen extends StatefulWidget {
  final String customerId;
  final Map<String, dynamic> initialData;

  const EditCustomerForOrderScreen({
    super.key,
    required this.customerId,
    required this.initialData,
  });

  @override
  State<EditCustomerForOrderScreen> createState() => _EditCustomerForOrderScreenState();
}

class _EditCustomerForOrderScreenState extends State<EditCustomerForOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _facebookController;
  late TextEditingController _emailController;
  late TextEditingController _userIdController;
  late TextEditingController _addressDetailController;

  final AuthService _authService = AuthService();

  List<Province> provinces = [];
  List<District> districts = [];
  List<Ward> wards = [];

  Province? selectedProvince;
  District? selectedDistrict;
  Ward? selectedWard;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _authService.initLocations();  // Khởi tạo dữ liệu địa phương

    provinces = _authService.getProvinces();

    // Khởi tạo controller, địa chỉ, selectedProvince, districts, wards như cũ
    // Ví dụ:
    _userIdController = TextEditingController(text: widget.customerId);
    _nameController = TextEditingController(text: widget.initialData['name'] ?? '');
    _phoneController = TextEditingController(text: widget.initialData['phone'] ?? '');
    _facebookController = TextEditingController(text: widget.initialData['facebook'] ?? '');
    _emailController = TextEditingController(text: widget.initialData['email'] ?? '');
    _addressDetailController = TextEditingController();

    // Xử lý phân tách address và tìm selectedProvince, selectedDistrict, selectedWard như trước

    setState(() {}); // cập nhật lại UI sau khi load xong


    // Lấy danh sách provinces, fallback [] nếu null
    provinces = _authService.getProvinces() ?? [];

    final address = widget.initialData['address'] as String? ?? '';

    if (address.isNotEmpty) {
      final parts = address.split(' - ');

      if (parts.isNotEmpty) {
        _addressDetailController.text = parts[0];
      }

      if (parts.length >= 4 && provinces.isNotEmpty) {
        final wardName = parts[parts.length - 3];
        final districtName = parts[parts.length - 2];
        final provinceName = parts[parts.length - 1];

        // Tìm tỉnh, fallback null nếu không tìm thấy
        selectedProvince = provinces.firstWhereOrNull((p) => p.name == provinceName);

        if (selectedProvince != null) {
          districts = _authService.getDistricts(selectedProvince!.code) ?? [];
          selectedDistrict = districts.firstWhereOrNull((d) => d.name == districtName);

          if (selectedDistrict != null) {
            wards = _authService.getWards(selectedProvince!.code, selectedDistrict!.code) ?? [];
            selectedWard = wards.firstWhereOrNull((w) => w.name == wardName);
          } else {
            wards = [];
            selectedWard = null;
          }
        } else {
          districts = [];
          wards = [];
          selectedDistrict = null;
          selectedWard = null;
        }
      } else {
        districts = [];
        wards = [];
        selectedProvince = null;
        selectedDistrict = null;
        selectedWard = null;
      }
    } else {
      districts = [];
      wards = [];
      selectedProvince = null;
      selectedDistrict = null;
      selectedWard = null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedProvince == null || selectedDistrict == null || selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn đầy đủ địa chỉ')),
      );
      return;
    }

    final addressFull =
        '${_addressDetailController.text.trim()} - ${selectedWard!.name} - ${selectedDistrict!.name} - ${selectedProvince!.name}';

    final dataToUpdate = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'facebook': _facebookController.text.trim(),
      'email': _emailController.text.trim(),
      'address': addressFull,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.customerId)
        .set(dataToUpdate, SetOptions(merge: true));

    Navigator.pop(context, dataToUpdate);
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.initialData['status'] ?? '';
    final statusColor = status == 'Bình thường' ? Colors.green : Colors.grey;

    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa thông tin khách hàng')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  if (widget.initialData['avatarUrl'] != null)
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(widget.initialData['avatarUrl']),
                    )
                  else
                    const CircleAvatar(radius: 40, child: Icon(Icons.person)),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _userIdController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Mã người dùng'),
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Điện thoại'),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập số điện thoại' : null,
              ),
              TextFormField(
                controller: _facebookController,
                decoration: const InputDecoration(labelText: 'Facebook'),
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              Text('Địa chỉ', style: Theme.of(context).textTheme.titleMedium),
              DropdownButtonFormField<Province>(
                value: selectedProvince,
                items: provinces
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                decoration: const InputDecoration(labelText: 'Tỉnh/Thành phố'),
                onChanged: (p) {
                  setState(() {
                    selectedProvince = p;
                    selectedDistrict = null;
                    selectedWard = null;
                    districts = p != null ? _authService.getDistricts(p.code) ?? [] : [];
                    wards = [];
                  });
                },
                validator: (v) => v == null ? 'Vui lòng chọn tỉnh/thành phố' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<District>(
                value: selectedDistrict,
                items: districts
                    .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                    .toList(),
                decoration: const InputDecoration(labelText: 'Quận/Huyện'),
                onChanged: (d) {
                  setState(() {
                    selectedDistrict = d;
                    selectedWard = null;
                    wards = (d != null && selectedProvince != null)
                        ? _authService.getWards(selectedProvince!.code, d.code) ?? []
                        : [];
                  });
                },
                validator: (v) => v == null ? 'Vui lòng chọn quận/huyện' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Ward>(
                value: selectedWard,
                items: wards
                    .map((w) => DropdownMenuItem(value: w, child: Text(w.name)))
                    .toList(),
                decoration: const InputDecoration(labelText: 'Xã/Phường'),
                onChanged: (w) {
                  setState(() {
                    selectedWard = w;
                  });
                },
                validator: (v) => v == null ? 'Vui lòng chọn xã/phường' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressDetailController,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ chi tiết',
                  hintText: 'Ví dụ: Số nhà, tên đường...',
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Vui lòng nhập địa chỉ chi tiết' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
