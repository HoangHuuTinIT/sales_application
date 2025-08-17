import 'package:ban_hang/services/owner_services/facebook_live_service.dart';
import 'package:flutter/material.dart';


class ListLivestreamsScreen extends StatefulWidget {
  const ListLivestreamsScreen({super.key});

  @override
  State<ListLivestreamsScreen> createState() => _ListLivestreamsScreenState();
}

class _ListLivestreamsScreenState extends State<ListLivestreamsScreen> {
  List<Map<String, dynamic>> livestreams = [];
  Map<String, dynamic>? page;
  bool isLoading = false; // Thêm biến này

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    page = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (page != null) _loadLiveVideos();
  }

  Future<void> _loadLiveVideos() async {
    setState(() => isLoading = true); // Bật loading
    try {
      final result = await FacebookLiveService()
          .getLivestreams(page!['pageId'], page!['accessToken']);
      setState(() => livestreams = result);
    } catch (e) {
      debugPrint("Lỗi load livestream: $e");
    } finally {
      setState(() => isLoading = false); // Tắt loading
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Livestream của ${page?['name']}")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator()) // Xoay xoay
          : livestreams.isEmpty
          ? const Center(child: Text("Không có livestream nào"))
          : ListView.builder(
        itemCount: livestreams.length,
        itemBuilder: (context, index) {
          final live = livestreams[index];
          return ListTile(
            title: Text(live['title'] ?? '(Không có tiêu đề)'),
            subtitle: Text("ID: ${live['id']}"),
            trailing: const Icon(Icons.comment),
            onTap: () {
              Navigator.pushNamed(
                context,
                '/comment-on-facebook',
                arguments: {
                  'livestreamId': live['id'],
                  'accessToken': page!['accessToken'],
                },
              );
            },
          );
        },
      ),
    );
  }
}

