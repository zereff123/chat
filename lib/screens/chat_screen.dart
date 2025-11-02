import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// Import model và widget mới
import '../models/message_model.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverEmail;

  const ChatScreen({super.key, required this.receiverId, required this.receiverEmail});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageCtrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final User currentUser = FirebaseAuth.instance.currentUser!;
  bool showEmojiPicker = false;

  String getChatId() => currentUser.uid.hashCode <= widget.receiverId.hashCode
      ? '${currentUser.uid}_${widget.receiverId}'
      : '${widget.receiverId}_${currentUser.uid}';

  Future<void> sendMessage() async {
    final text = messageCtrl.text.trim();
    if (text.isEmpty) return;
    final chatId = getChatId();

    await firestore.collection('chats').doc(chatId).collection('messages').add({
      'text': text,
      'imageUrl': '',
      'senderId': currentUser.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'isDeleted': false,
      'deletedFor': [],
    });

    messageCtrl.clear();
    scrollToBottom();
  }

  Future<void> pickAndSendImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final chatId = getChatId();
    final file = File(picked.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child('chat_images/$chatId/$fileName');

    try {
      await ref.putFile(file);
      final imgUrl = await ref.getDownloadURL();
      await firestore.collection('chats').doc(chatId).collection('messages').add({
        'text': '',
        'imageUrl': imgUrl,
        'senderId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'deletedFor': [],
      });
      scrollToBottom();
    } catch (e) {
      print('❌ Lỗi upload ảnh: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi upload ảnh: $e')),
      );
    }
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollCtrl.hasClients) {
        scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
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
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  controller: scrollCtrl,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msgDoc = messages[index];
                    final message = Message.fromDoc(msgDoc);
                    
                    return MessageBubble(
                      message: message,
                      currentUserId: currentUser.uid,
                      chatId: chatId,
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
                  onPressed: () => setState(() => showEmojiPicker = !showEmojiPicker),
                ),
                IconButton(
                  icon: const Icon(Icons.image, color: Colors.indigo),
                  onPressed: pickAndSendImage,
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
                  onPressed: sendMessage
                ),
              ],
            ),
          ),
          if (showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                textEditingController: messageCtrl,
                config: const Config(height: 256, emojiViewConfig: EmojiViewConfig(columns: 7)),
              ),
            ),
        ],
      ),
    );
  }
}