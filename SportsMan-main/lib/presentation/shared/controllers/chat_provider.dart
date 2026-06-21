import 'package:flutter/material.dart';
import '../../../core/data/app_repository.dart';
import '../../../core/auth/auth_controller.dart';

class ChatProvider with ChangeNotifier {
  final AppRepository _repo;
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

  ChatProvider(this._repo) {
    _fetchCurrentUserId();
  }

  Future<void> _fetchCurrentUserId() async {
    _currentUserId = AuthController.userId;
    if (_currentUserId == null) {
      final prof = await _repo.getUserProfile();
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

    _conversations = await _repo.getConversations();
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

    final convs = await _repo.getConversations();
    convs.insert(0, newConv);
    await _repo.saveConversations(convs);

    await loadConversations();
    return newConv;
  }

  Future<void> loadMessages(String conversationId) async {
    _isLoadingMessages = true;
    _messages = [];
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    final msgs = await _repo.getMessages(conversationId);
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

    // Persist via repository
    await _repo.saveMessages(conversationId, _messages);

    // Update lastMessage in local conversations list
    final convs = await _repo.getConversations();
    final convIndex = convs.indexWhere((c) => c['_id'] == conversationId);
    if (convIndex != -1) {
      convs[convIndex]['lastMessage'] = newMsg;
      final conv = convs.removeAt(convIndex);
      convs.insert(0, conv);
      await _repo.saveConversations(convs);
      _conversations = convs;
    }

    notifyListeners();

    // Simulate an offline auto-reply
    Future.delayed(const Duration(seconds: 1), () async {
      final replyId = DateTime.now().millisecondsSinceEpoch.toString();
      final replyMsg = {
        '_id': replyId,
        'conversationId': conversationId,
        'text': "This is an automated offline mock reply.",
        'senderId': 'provider_user_123',
        'createdAt': DateTime.now().toIso8601String(),
      };
      _messages.add(replyMsg);
      await _repo.saveMessages(conversationId, _messages);

      final currentConvs = await _repo.getConversations();
      final cIdx = currentConvs.indexWhere((c) => c['_id'] == conversationId);
      if (cIdx != -1) {
        currentConvs[cIdx]['lastMessage'] = replyMsg;
        await _repo.saveConversations(currentConvs);
        _conversations = currentConvs;
      }
      notifyListeners();
    });

    return true;
  }
}
