import 'package:dio/dio.dart';
import '../core/api.dart';

class ChatRepo {
  final _dio = Api.I.dio;

  /// Get available AI models
  Future<List<String>> models() async {
    final r = await _dio.get('/chat/models');
    final list = (r.data['models'] as List).cast<String>();
    return list;
  }

  /// Send a message to a conversation (creates one if not provided)
  ///
  /// Returns a map:
  /// `{ reply: String, model: String, lang: String, conversationId: int }`
  Future<Map<String, dynamic>> send({
    required String model,
    required String message,
    required String lang,
    int? conversationId,
  }) async {
    final r = await _dio.post(
      '/chat',
      data: {
        'model': model,
        'message': message,
        'lang': lang,
        'conversationId': conversationId,


        

      },
    );
    return (r.data as Map<String, dynamic>);
  }

  /// === Conversations Management ===

  /// Get all user conversations
  Future<List<Map<String, dynamic>>> listConversations() async {
    final r = await _dio.get('/conversations');
    return (r.data['items'] as List).cast<Map<String, dynamic>>();
  }

  /// Create a new conversation (optionally with a custom title)
  Future<Map<String, dynamic>> createConversation({String? title}) async {
    final r = await _dio.post('/conversations', data: {'title': title,});
    return r.data as Map<String, dynamic>; // {id, title}
  }

  /// Rename a conversation
  Future<void> renameConversation(int id, String title) async {
    await _dio.patch('/conversations/$id', data: {'title': title});
  }

  /// Delete a conversation (and all its messages)
  Future<void> deleteConversation(int id) async {
    await _dio.delete('/conversations/$id');
  }

  /// Load messages for one conversation
  Future<List<Map<String, dynamic>>> loadMessages(int id) async {
    final r = await _dio.get('/conversations/$id/messages');
    return (r.data['items'] as List).cast<Map<String, dynamic>>();
  }

  /// === Legacy endpoints (optional) ===

  Future<List<Map<String, dynamic>>> history() async {
    final r = await _dio.get('/history');
    return (r.data['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<String> summary() async {
    final r = await _dio.get('/summary');
    return (r.data['summary'] as String?) ?? '';
  }

  Future<String> summaryForConversation(int conversationId) async {
    try {
      final r = await _dio.get('/summary/$conversationId/summary');
      return (r.data['summary'] as String?) ?? 'No summary available';
    } catch (e) {
      print('Error fetching summary: $e');
      throw Exception('Failed to load summary: $e');
    }
  }
}
