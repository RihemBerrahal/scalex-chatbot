import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../chat/chat_repo.dart';

class SummaryScreen extends StatefulWidget {
  final int conversationId;
  const SummaryScreen({super.key, required this.conversationId});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _repo = ChatRepo();
  String _summary = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _repo.summaryForConversation(widget.conversationId);
      if (mounted) setState(() => _summary = s);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('error_loading_summary'.tr()),
          backgroundColor: const Color(0xFFe74c3c),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'summary'.tr(),
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
          ? const _Loading()
          : _summary.isEmpty
          ? _Empty(onRefresh: _refresh)
          : RefreshIndicator(
              backgroundColor: Colors.white,
              color: const Color(0xFF32a94d),
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Header(),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf8f9fa),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        _summary,
                        style: const TextStyle(
                          color: Color(0xFF2c2c2c),
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _Info(),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF32a94d), Color(0xFF2c8c41)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF32a94d).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.summarize_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          Text(
            'conversation_summary'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ai_generated_summary'.tr(),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF32a94d).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF32a94d).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF32a94d), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'summary_ai_generated_note'.tr(),
              style: const TextStyle(color: Color(0xFF2c2c2c), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF32a94d)),
          ),
          SizedBox(height: 16),
          Text(
            'Generating summary...',
            style: TextStyle(color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _Empty({required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return Center(
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
              Icons.summarize,
              color: Color(0xFF32a94d),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'no_summary'.tr(),
            style: const TextStyle(
              color: Color(0xFF2c2c2c),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'summary_will_appear_here'.tr(),
            style: const TextStyle(color: Color(0xFF666666), fontSize: 14),
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
            onPressed: onRefresh,
            child: Text(
              'refresh'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
