import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_image.dart';
import '../../shared/controllers/chat_provider.dart';

class ChatDetailsScreen extends StatefulWidget {
  const ChatDetailsScreen({super.key});

  @override
  State<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends State<ChatDetailsScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Local mock fallback messages if no matching backend conversation exists
  final List<Map<String, dynamic>> _mockMessages = [
    {
      'sender': 'MARCUS',
      'text': 'Hi! Looking for extra drilling sessions.',
      'time': '1:10 PM',
      'isUser': false,
    },
    {
      'sender': 'YOU',
      'text': 'Happy to help! Slots on Tuesday.',
      'time': '1:12 PM',
      'isUser': true,
    },
  ];

  String _conversationId = '';
  String _contactName = '';
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments;
      if (args is Map) {
        _conversationId = args['conversationId'] ?? '';
        _contactName = args['contactName'] ?? 'Chat';
        _avatarUrl = args['avatarUrl'] ?? '';
      } else if (args is String) {
        _contactName = args;
      }

      final chatProvider = context.read<ChatProvider>();

      // If conversationId is empty, try to resolve it from the contact name
      if (_conversationId.isEmpty && _contactName.isNotEmpty) {
        for (var c in chatProvider.conversations) {
          final participants = c['participants'];
          if (participants is List) {
            for (var p in participants) {
              if (p is Map) {
                final pName = '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim();
                if (pName.toLowerCase() == _contactName.toLowerCase()) {
                  _conversationId = c['_id'] ?? '';
                  break;
                }
              }
            }
          }
          if (_conversationId.isNotEmpty) break;
        }
      }

      if (_conversationId.isNotEmpty) {
        chatProvider.loadMessages(_conversationId).then((_) => _scrollToBottom());
      }
      setState(() {});
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _formatMessageTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final hourRaw = dateTime.hour;
      final hour = hourRaw == 0 ? 12 : (hourRaw > 12 ? hourRaw - 12 : hourRaw);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final amPm = hourRaw >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $amPm';
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final bool isRealChat = _conversationId.isNotEmpty;
    final bool isLoading = chatProvider.isLoadingMessages;
    final String currentUserId = chatProvider.currentUserId ?? '';

    // Determine messages list
    final List<dynamic> displayMessages = isRealChat ? chatProvider.messages : _mockMessages;

    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SporveIconButton(
            Icons.arrow_back,
            onTap: () => Get.back(),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            // User Avatar with green status dot
            Stack(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: SporveImage(
                      _avatarUrl.isNotEmpty
                          ? _avatarUrl
                          : 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&auto=format&fit=crop&q=80',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.person,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    height: 10,
                    width: 10,
                    decoration: BoxDecoration(
                      color: AppColors.slateText, // active dot
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ink, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Contact Name and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _contactName.isNotEmpty ? _contactName : 'Chat',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ACTIVE',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Phone Call Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SporveIconButton(
              Icons.phone,
              onTap: () {
                Get.snackbar(
                  'Phone Call',
                  'Calling $_contactName...',
                  backgroundColor: Colors.white,
                  colorText: Colors.black,
                );
              },
              size: 36,
              iconSize: 18,
            ),
          ),
          // Video Call Button
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 12),
            child: SporveIconButton(
              Icons.videocam,
              onTap: () {
                Get.snackbar(
                  'Video Call',
                  'Starting video call with $_contactName...',
                  backgroundColor: Colors.white,
                  colorText: Colors.black,
                );
              },
              size: 36,
              iconSize: 18,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.hairline,
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          // Message Bubbles Area
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.slateText))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    itemCount: displayMessages.length,
                    itemBuilder: (context, index) {
                      final msg = displayMessages[index];
                      
                      final bool isUser = isRealChat
                          ? (msg['senderId'] == currentUserId)
                          : (msg['isUser'] as bool);

                      final String senderName = isUser
                          ? 'YOU'
                          : (isRealChat ? _contactName.toUpperCase() : (msg['sender'] as String));

                      final String text = msg['text'] ?? '';
                      final String time = isRealChat
                          ? _formatMessageTime(msg['createdAt'])
                          : (msg['time'] ?? '');
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            // Sender Name Tag
                            Text(
                              senderName,
                              style: AppTypography.font(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Message Box
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                color: isUser ? AppColors.surface2 : AppColors.surface,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(AppRadii.card),
                                  topRight: const Radius.circular(AppRadii.card),
                                  bottomLeft: isUser ? const Radius.circular(AppRadii.card) : Radius.zero,
                                  bottomRight: isUser ? Radius.zero : const Radius.circular(AppRadii.card),
                                ),
                                border: Border.all(color: AppColors.hairline),
                              ),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Text(
                                text,
                                style: AppTypography.font(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Time stamp
                            Text(
                              time,
                              style: AppTypography.font(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          // Input Box Area (Figma styled rounded container)
          Container(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 32, top: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      border: Border.all(color: AppColors.hairline, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Attachment Icon
                        GestureDetector(
                          onTap: () {},
                          child: const Icon(Icons.attachment, color: AppColors.textSecondary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        // Emoji Icon
                        GestureDetector(
                          onTap: () {},
                          child: const Icon(Icons.sentiment_satisfied_alt, color: AppColors.textSecondary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        // Text Input
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13),
                            cursorColor: AppColors.slateText,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 13),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _handleSend(chatProvider),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Paper Plane Send Button
                SporveIconButton(
                  Icons.send,
                  onTap: () => _handleSend(chatProvider),
                  size: 56,
                  iconSize: 20,
                  filled: true,
                  circle: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleSend(ChatProvider chatProvider) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    if (_conversationId.isNotEmpty) {
      final success = await chatProvider.sendMessage(_conversationId, text);
      if (success) {
        _scrollToBottom();
      }
    } else {
      // Mock chat fallback behavior
      setState(() {
        _mockMessages.add({
          'sender': 'YOU',
          'text': text,
          'time': _formatMessageTime(DateTime.now().toIso8601String()),
          'isUser': true,
        });
      });
      _scrollToBottom();

      // Simulate mock auto coach reply after 1 sec
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _mockMessages.add({
              'sender': _contactName.toUpperCase(),
              'text': 'Sounds perfect! Let\'s get started.',
              'time': _formatMessageTime(DateTime.now().toIso8601String()),
              'isUser': false,
            });
          });
          _scrollToBottom();
        }
      });
    }
  }
}
