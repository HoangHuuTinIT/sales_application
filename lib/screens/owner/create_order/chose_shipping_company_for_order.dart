
import 'package:ban_hang/services/owner_services/shipping_company_service.dart';
import 'package:flutter/material.dart';


class ChoseShippingCompanyForOrderScreen extends StatelessWidget {
  const ChoseShippingCompanyForOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ShippingCompanyService().getAvailablePartners(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final partners = snapshot.data!;
        return Scaffold(
          appBar: AppBar(title: const Text('Chọn đối tác giao hàng')),
          body: ListView.builder(
            itemCount: partners.length,
            itemBuilder: (_, i) {
              final partner = partners[i];
              return ListTile(
                leading
                    : const Icon(Icons.local_shipping, size: 40),
                title: Text(partner['nameCopany']),
                onTap: () => Navigator.pop(context, partner),
              );
            },
          ),
        );
      },
    );
  }
}
