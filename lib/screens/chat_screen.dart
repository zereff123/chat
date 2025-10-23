import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverEmail;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverEmail,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageCtrl = TextEditingController();
  final firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser!;
  final scrollCtrl = ScrollController();
  bool showEmojiPicker = false;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    flutterLocalNotificationsPlugin.initialize(initSettings);

    Permission.notification.request();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? 'Tin nhắn mới';
      final body = message.notification?.body ?? 'Bạn có tin nhắn mới';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: $body'),
          duration: const Duration(seconds: 3),
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Người dùng mở app từ thông báo: ${message.data}');
    });
  }

  String getChatId() {
    if (currentUser.uid.hashCode <= widget.receiverId.hashCode) {
      return '${currentUser.uid}_${widget.receiverId}';
    } else {
      return '${widget.receiverId}_${currentUser.uid}';
    }
  }

  Future<void> sendMessage() async {
    final text = messageCtrl.text.trim();
    if (text.isEmpty) return;

    final chatId = getChatId();
    await firestore.collection('chats').doc(chatId).collection('messages').add({
      'text': text,
      'senderId': currentUser.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    messageCtrl.clear();
    setState(() => showEmojiPicker = false);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Tin nhắn đã gửi',
      'Bạn vừa gửi tin nhắn cho ${widget.receiverEmail}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_channel',
          'Chat Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatId = getChatId();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 8),
            Text(widget.receiverEmail, style: const TextStyle(fontSize: 16)),
          ],
        ),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  controller: scrollCtrl,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['senderId'] == currentUser.uid;
                    final time = msg['timestamp'] != null
                        ? DateFormat('HH:mm').format(
                            (msg['timestamp'] as Timestamp).toDate(),
                          )
                        : '';

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              isMe ? Colors.indigo[200] : Colors.grey.shade300,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft:
                                isMe ? const Radius.circular(14) : Radius.zero,
                            bottomRight:
                                isMe ? Radius.zero : const Radius.circular(14),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(msg['text'],
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                              time,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.grey[200],
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.emoji_emotions, color: Colors.indigo),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    setState(() => showEmojiPicker = !showEmojiPicker);
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: messageCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.indigo),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
          if (showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                textEditingController: messageCtrl,
                onEmojiSelected: (Category? category, Emoji emoji) {
                  messageCtrl
                    ..text += emoji.emoji
                    ..selection = TextSelection.fromPosition(
                      TextPosition(offset: messageCtrl.text.length),
                    );
                },
                onBackspacePressed: () {
                  if (messageCtrl.text.isNotEmpty) {
                    messageCtrl.text =
                        messageCtrl.text.characters.skipLast(1).toString();
                  }
                },
                config: const Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 7,
                    emojiSizeMax: 24,
                    backgroundColor: Colors.white,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    indicatorColor: Colors.indigo,
                    iconColorSelected: Colors.indigo,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}