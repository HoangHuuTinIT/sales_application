import 'dart:io';
import 'package:ban_hang/services/customer_services/customer_account_information_services.dart';
import 'package:ban_hang/utils/message.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vietnam_provinces/vietnam_provinces.dart';

class CustomerAccountInformationScreen extends StatefulWidget {
  const CustomerAccountInformationScreen({super.key});

  @override
  State<CustomerAccountInformationScreen> createState() =>
      _CustomerAccountInformationScreenState();
}

class _CustomerAccountInformationScreenState
    extends State<CustomerAccountInformationScreen> {
  final _auth = FirebaseAuth.instance;
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final detailAddressController = TextEditingController();

  Province? selectedProvince;
  District? selectedDistrict;
  Ward? selectedWard;
  String? gender;

  List<Province> provinces = [];
  List<District> districts = [];
  List<Ward> wards = [];

  String? _imageUrl; // ảnh đang dùng
  File? _pickedImageFile; // ảnh tạm thời

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    VietnamProvinces.initialize().then((_) {
      provinces = VietnamProvinces.getProvinces();
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    if (data == null) return;

    nameController.text = data['name'] ?? '';
    emailController.text = data['email'] ?? '';
    phoneController.text = data['phone'] ?? '';
    gender = data['gender'] ?? '';
    _imageUrl = data['avatarUrl'];

    final address = data['address'] ?? '';
    final parts = address.split(' - ');
    if (parts.isNotEmpty) detailAddressController.text = parts[0];

    if (parts.length >= 4) {
      final wardName = parts[1].replaceFirst('Xã ', '');
      final districtName = parts[2].replaceFirst('Huyện ', '');
      final provinceName = parts[3].replaceFirst('Tỉnh ', '');

      selectedProvince = provinces.firstWhere(
              (p) => p.name == provinceName,
          orElse: () => provinces.first);
      districts = VietnamProvinces.getDistricts(
          provinceCode: selectedProvince!.code);

      selectedDistrict = districts.firstWhere(
              (d) => d.name == districtName,
          orElse: () => districts.first);
      wards = VietnamProvinces.getWards(
        provinceCode: selectedProvince!.code,
        districtCode: selectedDistrict!.code,
      );
      selectedWard = wards.firstWhere((w) => w.name == wardName,
          orElse: () => wards.first);
    }

    setState(() {});
  }

  Future<void> _pickImage() async {
    final file =
    await CustomerAccountInformationServices().pickImageFile();
    if (file != null) {
      setState(() {
        _pickedImageFile = file;
      });
    }
  }

  void _changePhone() async {
    final newPhone =
    await CustomerAccountInformationServices().verifyAndChangePhone(context);
    if (newPhone != null) {
      final formattedPhone = message.formatVNPhone(newPhone);
      phoneController.text = formattedPhone;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'phone': formattedPhone,
        });
      }
    }
  }

  void _changeEmail() async {
    final newEmail =
    await CustomerAccountInformationServices().verifyAndChangeEmail(context);
    if (newEmail != null) {
      emailController.text = newEmail;
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      isLoading = true;
    });

    String? finalAvatarUrl = _imageUrl;

    if (_pickedImageFile != null) {
      final url = await CustomerAccountInformationServices()
          .uploadAvatar(_pickedImageFile!);
      if (url != null) {
        finalAvatarUrl = url;
      }
    }

    await CustomerAccountInformationServices().updateAccountInfo(
      name: nameController.text.trim(),
      gender: gender ?? '',
      province: selectedProvince?.name ?? '',
      district: selectedDistrict?.name ?? '',
      ward: selectedWard?.name ?? '',
      detailAddress: detailAddressController.text.trim(),
    );

    if (finalAvatarUrl != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'avatarUrl': finalAvatarUrl,
        });
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật thành công')),
      );
    }

    setState(() {
      isLoading = false;
      _pickedImageFile = null;
      _imageUrl = finalAvatarUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản của tôi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Center(
              child: InkWell(
                onTap: _pickImage,
                child: _pickedImageFile != null
                    ? CircleAvatar(
                  radius: 50,
                  backgroundImage: FileImage(_pickedImageFile!),
                )
                    : (_imageUrl != null
                    ? CachedNetworkImage(
                  imageUrl: _imageUrl!,
                  imageBuilder: (context, imageProvider) =>
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: imageProvider,
                      ),
                  placeholder: (context, url) =>
                  const CircularProgressIndicator(),
                  errorWidget: (context, url, error) =>
                  const CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50)),
                )
                    : const CircleAvatar(
                  radius: 50,
                  child: Icon(Icons.person, size: 50),
                )),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Họ tên'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Giới tính:'),
                Radio<String>(
                  value: 'Nam',
                  groupValue: gender,
                  onChanged: (value) => setState(() => gender = value),
                ),
                const Text('Nam'),
                Radio<String>(
                  value: 'Nữ',
                  groupValue: gender,
                  onChanged: (value) => setState(() => gender = value),
                ),
                const Text('Nữ'),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Email',
                suffixIcon: TextButton(
                  onPressed: _changeEmail,
                  child: const Text('Thay đổi'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Số điện thoại',
                suffixIcon: TextButton(
                  onPressed: _changePhone,
                  child: const Text('Thay đổi'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Province>(
              value: selectedProvince,
              items: provinces
                  .map((p) =>
                  DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              decoration:
              const InputDecoration(labelText: 'Tỉnh/Thành phố'),
              onChanged: (p) {
                setState(() {
                  selectedProvince = p;
                  selectedDistrict = null;
                  selectedWard = null;
                  districts = VietnamProvinces.getDistricts(
                      provinceCode: p!.code);
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<District>(
              value: selectedDistrict,
              items: districts
                  .map((d) =>
                  DropdownMenuItem(value: d, child: Text(d.name)))
                  .toList(),
              decoration: const InputDecoration(labelText: 'Quận/Huyện'),
              onChanged: (d) {
                setState(() {
                  selectedDistrict = d;
                  selectedWard = null;
                  wards = VietnamProvinces.getWards(
                    provinceCode: selectedProvince!.code,
                    districtCode: d!.code,
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Ward>(
              value: selectedWard,
              items: wards
                  .map((w) =>
                  DropdownMenuItem(value: w, child: Text(w.name)))
                  .toList(),
              decoration: const InputDecoration(labelText: 'Phường/Xã'),
              onChanged: (w) => setState(() => selectedWard = w),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailAddressController,
              decoration: const InputDecoration(
                  labelText: 'Thôn/Xóm/Ngõ/Số nhà'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _handleSave,
              child: isLoading
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Đang lưu...'),
                ],
              )
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
