// Verifies the chat data path: optimistic send -> real persistence (postMessage),
// and realtime delivery with de-dupe (our own echo ignored, others appended).
//   flutter test test/chat_realtime_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_structure/core/auth/auth_service.dart';
import 'package:flutter_structure/core/auth/app_user.dart';
import 'package:flutter_structure/core/data/app_repository.dart';
import 'package:flutter_structure/presentation/shared/controllers/chat_provider.dart';

class _FakeRepo implements AppRepository {
  final List<dynamic> store = [];
  void Function(Map<String, dynamic>)? _cb;
  void emit(Map<String, dynamic> m) => _cb?.call(m);

  @override
  Future<Map<String, dynamic>> getUserProfile() async => {'_id': 'me'};
  @override
  Future<List<dynamic>> getMessages(String c) async => List.from(store);
  @override
  Future<List<dynamic>> getConversations() async => [
        <String, dynamic>{'_id': 'conv_1', 'lastMessage': null},
      ];
  @override
  Future<Map<String, dynamic>?> postMessage(String c, String body) async {
    final m = {
      '_id': 'real-${store.length}',
      'conversationId': c,
      'text': body,
      'senderId': 'me',
      'createdAt': '2026-06-28T10:0${store.length}:00Z',
    };
    store.add(m);
    return m;
  }

  @override
  Future<void Function()> subscribeMessages(
      String c, void Function(Map<String, dynamic>) onMessage) async {
    _cb = onMessage;
    return () => _cb = null;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeAuth implements AuthService {
  @override
  AppUser? get currentUser => const AppUser(id: 'me', role: 'searcher');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('persist via postMessage; realtime appends others, de-dupes own echo',
      () async {
    final repo = _FakeRepo();
    final chat = ChatProvider(repo, _FakeAuth());
    await chat.loadMessages('conv_1');
    await chat.subscribeToConversation('conv_1');

    // send -> persisted; optimistic temp swapped for the real row
    expect(await chat.sendMessage('conv_1', 'hello'), true);
    expect(chat.messages.length, 1);
    expect(chat.messages.last['text'], 'hello');
    final sentId = chat.messages.last['_id'];

    // realtime echoes OUR OWN message (same id) -> ignored (no duplicate)
    repo.emit({'_id': sentId, 'conversationId': 'conv_1', 'text': 'hello', 'senderId': 'me', 'createdAt': '2026-06-28T10:00:00Z'});
    expect(chat.messages.length, 1, reason: 'own echo de-duped');

    // realtime delivers the OTHER participant's message -> appended live
    repo.emit({'_id': 'remote-1', 'conversationId': 'conv_1', 'text': 'hi back', 'senderId': 'them', 'createdAt': '2030-01-01T00:00:00Z'});
    expect(chat.messages.length, 2);
    expect(chat.messages.last['text'], 'hi back');

    // a duplicate of the remote message is ignored too
    repo.emit({'_id': 'remote-1', 'conversationId': 'conv_1', 'text': 'hi back', 'senderId': 'them', 'createdAt': '2030-01-01T00:00:00Z'});
    expect(chat.messages.length, 2, reason: 'duplicate remote de-duped');
  });
}
