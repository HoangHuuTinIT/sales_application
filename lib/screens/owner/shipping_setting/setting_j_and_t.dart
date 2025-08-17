import 'package:ban_hang/services/auth_services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:ban_hang/services/owner_services/setting_j_and_t_services.dart';


class SettingJAndTScreen extends StatefulWidget {
  const SettingJAndTScreen({super.key});

  @override
  State<SettingJAndTScreen> createState() => _SettingJAndTScreenState();
}

class _SettingJAndTScreenState extends State<SettingJAndTScreen> {
  bool isDefaultTab = true;

  // form controllers
  final apiAccountController = TextEditingController();
  final customerCodeController = TextEditingController();
  final keyController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final addressController = TextEditingController();

  final AuthService _authService = AuthService();

  // selections
  int? selectedProvinceCode;
  int? selectedDistrictCode;
  int? selectedWardCode;

  // nâng cao
  String orderType = "1"; // mặc định đơn bình thường
  String serviceType = "1"; // Pickup mặc định
  String payType = "CC_CASH";
  String productType = "EXPRESS";
  String goodsType = "bm000010"; // hàng hóa mặc định
  String deliveryType = "1";
  String isInsured = "0";
  @override
  void dispose() {
    apiAccountController.dispose();
    customerCodeController.dispose();
    keyController.dispose();
    passwordController.dispose();
    nameController.dispose();
    mobileController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _authService.initLocations(); // load dữ liệu tỉnh huyện xã
    _loadConfig(); // load dữ liệu từ Firestore
  }

  Future<void> _loadConfig() async {
    final data = await SettingJAndTServices.getConfig();
    if (data == null) return;

    final provinces = _authService.getProvinces();
    final districts = data["prov"] != null
        ? _authService.getDistricts(
        provinces.firstWhere((p) => p.name == data["prov"]).code)
        : [];
    final wards = (data["prov"] != null && data["city"] != null)
        ? _authService.getWards(
      provinces.firstWhere((p) => p.name == data["prov"]).code,
      districts.firstWhere((d) => d.name == data["city"]).code,
    )
        : [];

    setState(() {
      customerCodeController.text = data["customerCode"] ?? "";
      keyController.text = data["key"] ?? "";
      passwordController.text = data["password"] ?? "";
      nameController.text = data["name"] ?? "";
      mobileController.text = data["mobile"] ?? "";
      addressController.text = data["address"] ?? "";

      // tìm code dựa vào tên đã lưu
      if (data["prov"] != null) {
        final province = provinces.firstWhere((p) => p.name == data["prov"]);
        selectedProvinceCode = province.code;

        if (data["city"] != null) {
          final district = _authService
              .getDistricts(province.code)
              .firstWhere((d) => d.name == data["city"]);
          selectedDistrictCode = district.code;

          if (data["area"] != null) {
            final ward = _authService
                .getWards(province.code, district.code)
                .firstWhere((w) => w.name == data["area"]);
            selectedWardCode = ward.code;
          }
        }
      }

      // nâng cao
      orderType = data["orderType"] ?? orderType;
      serviceType = data["serviceType"] ?? serviceType;
      payType = data["payType"] ?? payType;
      productType = data["productType"] ?? productType;
      goodsType = data["goodsType"] ?? goodsType;
      deliveryType = data["deliveryType"] ?? deliveryType;
      isInsured = data["isInsured"] ?? isInsured;
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cài đặt J&T Express")),
      body: Column(
        children: [
          // Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text("Mặc định"),
                selected: isDefaultTab,
                onSelected: (selected) {
                  setState(() => isDefaultTab = true);
                },
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text("Nâng cao"),
                selected: !isDefaultTab,
                onSelected: (selected) {
                  setState(() => isDefaultTab = false);
                },
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: isDefaultTab ? _buildDefaultForm() : _buildAdvancedForm(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () async {
            if (isDefaultTab) {
              final provName = selectedProvinceCode != null
                  ? _authService.getProvinces()
                  .firstWhere((p) => p.code == selectedProvinceCode!)
                  .name
                  : null;
              final cityName = selectedDistrictCode != null
                  ? _authService.getDistricts(selectedProvinceCode!)
                  .firstWhere((d) => d.code == selectedDistrictCode!)
                  .name
                  : null;
              final areaName = selectedWardCode != null
                  ? _authService.getWards(selectedProvinceCode!, selectedDistrictCode!)
                  .firstWhere((w) => w.code == selectedWardCode!)
                  .name
                  : null;

              await SettingJAndTServices.saveDefaultConfig(
                apiAccount: apiAccountController.text,
                customerCode: customerCodeController.text,
                key: keyController.text,
                password: passwordController.text,
                name: nameController.text,
                mobile: mobileController.text,
                prov: provName,
                city: cityName,
                area: areaName,
                address: addressController.text,
              );
            } else {
              await SettingJAndTServices.saveAdvancedConfig(
                orderType: orderType,
                serviceType: serviceType,
                payType: payType,
                productType: productType,
                goodsType: goodsType,
                deliveryType: deliveryType,
                isInsured: isInsured,
              );
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Đã lưu cấu hình")),
            );
          },

          child: const Text("Lưu"),
        ),
      ),
    );
  }

  /// FORM MẶC ĐỊNH
  Widget _buildDefaultForm() {
    final provinces = _authService.getProvinces();
    final districts = selectedProvinceCode != null
        ? _authService.getDistricts(selectedProvinceCode!)
        : [];
    final wards = (selectedProvinceCode != null && selectedDistrictCode != null)
        ? _authService.getWards(selectedProvinceCode!, selectedDistrictCode!)
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: customerCodeController,
          decoration: const InputDecoration(labelText: "Customer Code"),
        ),
        TextField(
          controller: keyController,
          decoration: const InputDecoration(labelText: "Key"),
        ),
        TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: "Password"),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextField(controller: nameController, decoration: const InputDecoration(labelText: "Tên người gửi")),
        TextField(controller: mobileController, decoration: const InputDecoration(labelText: "SĐT người gửi")),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: "Tỉnh/Thành"),
          value: selectedProvinceCode,
          items: provinces
              .map((p) => DropdownMenuItem<int>(value: p.code, child: Text(p.name)))
              .toList(),
          onChanged: (val) => setState(() {
            selectedProvinceCode = val;
            selectedDistrictCode = null;
            selectedWardCode = null;
          }),
        ),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: "Quận/Huyện"),
          value: selectedDistrictCode,
          items: districts
              .map((d) => DropdownMenuItem<int>(
            value: d.code,
            child: Text(d.name),
          ))
              .toList(),
          onChanged: (val) => setState(() {
            selectedDistrictCode = val;
            selectedWardCode = null;
          }),
        ),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: "Phường/Xã"),
          value: selectedWardCode,
          items: wards
              .map((w) => DropdownMenuItem<int>(
            value: w.code,
            child: Text(w.name),
          ))
              .toList(),
          onChanged: (val) => setState(() => selectedWardCode = val),
        ),
        TextField(controller: addressController, decoration: const InputDecoration(labelText: "Địa chỉ chi tiết")),
      ],
    );
  }

  /// FORM NÂNG CAO
  Widget _buildAdvancedForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField(
          value: orderType,
          decoration: const InputDecoration(labelText: "Loại đơn đặt"),
          items: const [
            DropdownMenuItem(value: "1", child: Text("Đơn bình thường")),
            DropdownMenuItem(value: "2", child: Text("Đơn chuyển hoàn")),
          ],
          onChanged: (val) => setState(() => orderType = val!),
        ),
        DropdownButtonFormField(
          value: serviceType,
          decoration: const InputDecoration(labelText: "Loại dịch vụ"),
          items: const [
            DropdownMenuItem(value: "1", child: Text("Pickup")),
            DropdownMenuItem(value: "6", child: Text("Drop off")),
          ],
          onChanged: (val) => setState(() => serviceType = val!),
        ),
        DropdownButtonFormField(
          value: payType,
          decoration: const InputDecoration(labelText: "Phương thức thanh toán"),
          items: const [
            DropdownMenuItem(value: "PP_PM", child: Text("Thanh toán cuối tháng")),
            DropdownMenuItem(value: "PP_CASH", child: Text("Người gửi thanh toán")),
            DropdownMenuItem(value: "CC_CASH", child: Text("Người nhận thanh toán")),
          ],
          onChanged: (val) => setState(() => payType = val!),
        ),
        DropdownButtonFormField(
          value: productType,
          decoration: const InputDecoration(labelText: "Loại vận chuyển"),
          items: const [
            DropdownMenuItem(value: "EXPRESS", child: Text("EXPRESS")),
            DropdownMenuItem(value: "FAST", child: Text("FAST")),
            DropdownMenuItem(value: "SUPER", child: Text("SUPER")),
          ],
          onChanged: (val) => setState(() => productType = val!),
        ),
        DropdownButtonFormField(
          value: goodsType,
          decoration: const InputDecoration(labelText: "Loại hàng hóa"),
          items: const [
            DropdownMenuItem(value: "bm000001", child: Text("Tài liệu")),
            DropdownMenuItem(value: "bm000010", child: Text("Hàng hóa")),
            DropdownMenuItem(value: "bm000011", child: Text("Hàng tươi sống")),
          ],
          onChanged: (val) => setState(() => goodsType = val!),
        ),
        DropdownButtonFormField(
          value: deliveryType,
          decoration: const InputDecoration(labelText: "Loại phát hàng"),
          items: const [
            DropdownMenuItem(value: "1", child: Text("Phát bình thường")),
            DropdownMenuItem(value: "2", child: Text("Khách hàng tự đến lấy")),
          ],
          onChanged: (val) => setState(() => deliveryType = val!),
        ),
        DropdownButtonFormField(
          value: isInsured,
          decoration: const InputDecoration(labelText: "Khai giá"),
          items: const [
            DropdownMenuItem(value: "0", child: Text("Không")),
            DropdownMenuItem(value: "1", child: Text("Có")),
          ],
          onChanged: (val) => setState(() => isInsured = val!),
        ),
      ],
    );
  }
}
