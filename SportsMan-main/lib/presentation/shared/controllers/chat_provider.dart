import 'package:flutter/material.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/auth/auth_controller.dart';

class ChatProvider with ChangeNotifier {
  List<dynamic> _conversations = [];
  List<dynamic> _messages = [];
  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  String? _currentUserId;

  List<dynamic> get conversations => _conversations;
  List<dynamic> get messages => _messages;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get currentUserId => _currentUserId;

  ChatProvider() {
    _fetchCurrentUserId();
  }

  Future<void> _fetchCurrentUserId() async {
    _currentUserId = AuthController.userId;
    if (_currentUserId == null) {
      final prof = MockData.userProfile;
      if (prof.isNotEmpty && prof['_id'] != null) {
        _currentUserId = prof['_id'];
        await AuthController.saveUserId(_currentUserId!);
      }
    }
  }

  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));
    await _fetchCurrentUserId();

    _conversations = MockData.conversations;
    _isLoadingConversations = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> initiateConversation(String recipientId, {String? programId}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newConv = {
      "_id": "conv_${DateTime.now().millisecondsSinceEpoch}",
      "participants": [
        {
          "_id": _currentUserId,
          "firstName": "You",
          "lastName": "",
          "role": AuthController.activeRole ?? "searcher"
        },
        {
          "_id": recipientId,
          "firstName": "Participant",
          "lastName": "",
          "role": "provider"
        }
      ],
      "programId": programId,
      "lastMessage": null
    };

    final convs = MockData.conversations;
    convs.insert(0, newConv);
    MockData.conversations = convs;

    await loadConversations();
    return newConv;
  }

  Future<void> loadMessages(String conversationId) async {
    _isLoadingMessages = true;
    _messages = [];
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    final msgs = MockData.getMessages(conversationId);
    _messages = List.from(msgs);
    _messages.sort((a, b) {
      final aTime = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

    _isLoadingMessages = false;
    notifyListeners();
  }

  Future<bool> sendMessage(String conversationId, String text) async {
    if (text.trim().isEmpty) return false;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final newMsg = {
      '_id': tempId,
      'conversationId': conversationId,
      'text': text,
      'senderId': _currentUserId ?? AuthController.userId ?? '',
      'createdAt': DateTime.now().toIso8601String(),
    };

    _messages.add(newMsg);
    notifyListeners();

    // Persist to mock data
    MockData.saveMessages(conversationId, _messages);

    // Update lastMessage in local conversations list
    final convs = MockData.conversations;
    final convIndex = convs.indexWhere((c) => c['_id'] == conversationId);
    if (convIndex != -1) {
      convs[convIndex]['lastMessage'] = newMsg;
      final conv = convs.removeAt(convIndex);
      convs.insert(0, conv);
      MockData.conversations = convs;
      _conversations = convs;
    }
    
    notifyListeners();

    // Simulate an offline auto-reply
    Future.delayed(const Duration(seconds: 1), () {
      final replyId = DateTime.now().millisecondsSinceEpoch.toString();
      final replyMsg = {
        '_id': replyId,
        'conversationId': conversationId,
        'text': "This is an automated offline mock reply.",
        'senderId': 'provider_user_123',
        'createdAt': DateTime.now().toIso8601String(),
      };
      _messages.add(replyMsg);
      MockData.saveMessages(conversationId, _messages);
      
      final currentConvs = MockData.conversations;
      final cIdx = currentConvs.indexWhere((c) => c['_id'] == conversationId);
      if (cIdx != -1) {
        currentConvs[cIdx]['lastMessage'] = replyMsg;
        MockData.conversations = currentConvs;
        _conversations = currentConvs;
      }
      notifyListeners();
    });

    return true;
  }
}
