import 'package:flutter/material.dart';
import '../../../core/data/app_repository.dart';
import '../../../core/auth/auth_service.dart';

class ChatProvider with ChangeNotifier {
  final AppRepository _repo;
  final AuthService _auth;
  List<dynamic> _conversations = [];
  List<dynamic> _messages = [];
  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  String? _currentUserId;

  // AI reply drafting (coach-only "Draft reply" affordance).
  bool _isDrafting = false;
  String? _draftError;

  List<dynamic> get conversations => _conversations;
  List<dynamic> get messages => _messages;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get currentUserId => _currentUserId;
  bool get isDrafting => _isDrafting;
  String? get draftError => _draftError;

  /// Only coaches (providers) may draft replies — message-draft authorizes that
  /// the caller owns the provider, so the affordance is provider-only in the UI.
  bool get isProvider => _auth.currentUser?.role == 'provider';

  ChatProvider(this._repo, this._auth) {
    _fetchCurrentUserId();
  }

  Future<void> _fetchCurrentUserId() async {
    _currentUserId = _auth.currentUser?.id;
    if (_currentUserId == null) {
      final prof = await _repo.getUserProfile();
      if (prof.isNotEmpty && prof['_id'] != null) {
        _currentUserId = prof['_id'];
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

  Future<Map<String, dynamic>?> initiateConversation(
    String recipientId, {
    String? programId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newConv = {
      "_id": "conv_${DateTime.now().millisecondsSinceEpoch}",
      "participants": [
        {
          "_id": _currentUserId,
          "firstName": "You",
          "lastName": "",
          "role": _auth.currentUser?.role ?? "searcher",
        },
        {
          "_id": recipientId,
          "firstName": "Participant",
          "lastName": "",
          "role": "provider",
        },
      ],
      "programId": programId,
      "lastMessage": null,
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
      final aTime =
          DateTime.tryParse(a['createdAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          DateTime.tryParse(b['createdAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

    _isLoadingMessages = false;
    notifyListeners();
  }

  /// Calls the `message-draft` Edge Function with the current thread's recent
  /// messages and returns 1–2 editable draft strings. NEVER sends — the UI
  /// pre-fills the composer with the chosen draft and the coach sends manually.
  /// Returns an empty list on error/refusal (see [draftError]).
  Future<List<String>> draftReply({
    String intent = 'reply',
    String? childFirstName,
    String? bookingContext,
  }) async {
    _isDrafting = true;
    _draftError = null;
    notifyListeners();

    // Build thread context from the loaded messages (most recent ~10), tagging
    // the coach's own messages 'coach' and everything else 'parent'.
    final uid = _currentUserId ?? _auth.currentUser?.id ?? '';
    final recent = _messages.length > 10
        ? _messages.sublist(_messages.length - 10)
        : _messages;
    final threadContext = recent
        .map(
          (m) => {
            'role': (m['senderId'] == uid) ? 'coach' : 'parent',
            'body': (m['text'] ?? '').toString(),
          },
        )
        .where((m) => (m['body'] as String).trim().isNotEmpty)
        .toList();

    if (threadContext.isEmpty) {
      _isDrafting = false;
      _draftError = 'No messages yet to draft a reply from.';
      notifyListeners();
      return [];
    }

    final res = await _repo.draftMessage({
      'threadContext': threadContext,
      'intent': intent,
      if (childFirstName != null && childFirstName.trim().isNotEmpty)
        'childFirstName': childFirstName,
      if (bookingContext != null && bookingContext.trim().isNotEmpty)
        'bookingContext': bookingContext,
    });

    _isDrafting = false;

    if (res['error'] != null) {
      _draftError = res['error'].toString();
      notifyListeners();
      return [];
    }

    final result = res['result'];
    if (result is Map && result['type'] == 'drafts') {
      final drafts = (result['drafts'] as List?) ?? const [];
      final out = drafts
          .map((d) => (d is Map ? d['text']?.toString() : d?.toString()) ?? '')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      if (out.isEmpty) {
        _draftError = 'No draft was returned. Please try again.';
      }
      notifyListeners();
      return out;
    }

    // needs_revision (guardrail refused) or any unexpected shape.
    _draftError =
        'The assistant couldn\'t produce a safe draft for this thread.';
    notifyListeners();
    return [];
  }

  Future<bool> sendMessage(String conversationId, String text) async {
    if (text.trim().isEmpty) return false;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final newMsg = {
      '_id': tempId,
      'conversationId': conversationId,
      'text': text,
      'senderId': _currentUserId ?? _auth.currentUser?.id ?? '',
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
    // NOTE: no fabricated auto-reply. Real two-way chat requires real
    // conversations/messages rows (provider participant) — a separate feature;
    // until then a sent message simply shows for this session.
    return true;
  }
}
