import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../chat/chat_repo.dart';
import '../chat/widgets/chat_bubble.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _repo = ChatRepo();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.history();
      setState(() => _items = data.reversed.toList()); // oldest → newest
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_loading_history'.tr()),
            backgroundColor: const Color(0xFFe74c3c),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  String _formatTimestamp(String timestamp) {
    try {
      // Parse the timestamp as UTC (since it's stored as GMT in database)
      final date = DateTime.parse('${timestamp}Z').toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'just_now'.tr();
      if (difference.inHours < 1)
        return '${difference.inMinutes}m ${'ago'.tr()}';
      if (difference.inDays < 1) return '${difference.inHours}h ${'ago'.tr()}';
      if (difference.inDays < 7) return '${difference.inDays}d ${'ago'.tr()}';

      // For older messages, show the localized date
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp; // Fallback to original timestamp if parsing fails
    }
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, int index) {
    final isUser = item['role'] == 'user';
    final timestamp = item['ts']; // Your API uses 'ts' field
    final showTimestamp =
        index == 0 || _items[index - 1]['role'] == 'assistant' && isUser;

    return Column(
      children: [
        if (showTimestamp && timestamp != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF32a94d).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF32a94d).withOpacity(0.3),
                ),
              ),
              child: Text(
                _formatTimestamp(timestamp),
                style: const TextStyle(
                  color: Color(0xFF32a94d),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 8, top: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF32a94d),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        'assistant'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ChatBubble(text: item['content'] ?? '', isUser: isUser),
                ],
              ),
            ),
            if (isUser)
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(left: 8, top: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2c2c2c),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 16),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'history'.tr(),
          style: const TextStyle(
            color: Color(0xFF2c2c2c),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2c2c2c)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2c2c2c)),
            onPressed: _loading ? null : _refresh,
            tooltip: 'refresh'.tr(),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF32a94d),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading history...',
                    style: TextStyle(color: Color(0xFF666666)),
                  ),
                ],
              ),
            )
          : _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFf8f9fa),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.history,
                      color: Color(0xFF32a94d),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'no_history'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF2c2c2c),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'conversations_will_appear_here'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF32a94d),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _refresh,
                    child: Text(
                      'refresh'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              backgroundColor: Colors.white,
              color: const Color(0xFF32a94d),
              onRefresh: _refresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                itemBuilder: (_, i) => _buildHistoryItem(_items[i], i),
              ),
            ),
    );
  }
}
