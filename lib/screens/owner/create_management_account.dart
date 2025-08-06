import 'package:ban_hang/services/auth_services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:vietnam_provinces/vietnam_provinces.dart';

import '../../services/owner_services/create_management_account_services.dart';

class CreateManagementAccountScreen extends StatefulWidget {
  const CreateManagementAccountScreen({super.key});

  @override
  State<CreateManagementAccountScreen> createState() =>
      _CreateManagementAccountScreenState();
}

class _CreateManagementAccountScreenState
    extends State<CreateManagementAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final detailAddressController = TextEditingController();

  List<Province> provinces = [];
  List<District> districts = [];
  List<Ward> wards = [];

  Province? selectedProvince;
  District? selectedDistrict;
  Ward? selectedWard;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    AuthService().initLocations().then((_) {
      setState(() {
        provinces = AuthService().getProvinces();
      });
    });
  }

  void _handleCreateAccount() async {
    if (!_formKey.currentState!.validate() ||
        selectedProvince == null ||
        selectedDistrict == null ||
        selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }
    setState(() => isLoading = true);

    final result = await CreateManagementAccountService().createAccount(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      phone: phoneController.text.trim(),
      detailAddress: detailAddressController.text.trim(),
      province: selectedProvince!.name,
      district: selectedDistrict!.name,
      ward: selectedWard!.name,
    );
    setState(() => isLoading = false);
    if (result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo tài khoản thành công')),
      );
      // Navigator.pushNamed(context,'create-management-account');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo tài khoản thất bại')),
      );
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cấp tài khoản quản lý')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: nameController,
                  validator: RequiredValidator(errorText: 'Không được để trống'),
                  decoration: const InputDecoration(
                    labelText: 'Họ tên',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  validator: MultiValidator([
                    RequiredValidator(errorText: 'Không được để trống'),
                    EmailValidator(errorText: 'Email không hợp lệ'),
                  ]),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  validator: RequiredValidator(errorText: 'Không được để trống'),
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
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
                      districts = AuthService().getDistricts(p!.code);
                      wards = [];
                    });
                  },
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
                      wards = AuthService()
                          .getWards(selectedProvince!.code, d!.code);
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Ward>(
                  value: selectedWard,
                  items: wards
                      .map((w) => DropdownMenuItem(value: w, child: Text(w.name)))
                      .toList(),
                  decoration: const InputDecoration(labelText: 'Phường/Xã'),
                  onChanged: (w) => setState(() => selectedWard = w),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: detailAddressController,
                  validator: RequiredValidator(errorText: 'Không được để trống'),
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ chi tiết',
                    prefixIcon: Icon(Icons.home),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isLoading ? null : _handleCreateAccount,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Tạo tài khoản'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
