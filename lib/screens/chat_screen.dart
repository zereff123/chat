import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final imgUrl = await snapshot.ref.getDownloadURL();

      await firestore.collection('chats').doc(chatId).collection('messages').add({
        'text': '',
        'imageUrl': imgUrl,
        'senderId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      scrollToBottom();
    } catch (e) {
      print('❌ Lỗi upload ảnh: $e');
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
                    final msg = messages[index];
                    final isMe = msg['senderId'] == currentUser.uid;
                    final time = msg['timestamp'] != null
                        ? DateFormat('HH:mm').format((msg['timestamp'] as Timestamp).toDate())
                        : '';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.indigo[200] : Colors.grey.shade300,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: isMe ? const Radius.circular(14) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(14),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (msg['imageUrl'] != null && msg['imageUrl'] != '')
                              GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: Image.network(msg['imageUrl']),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    msg['imageUrl'],
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return SizedBox(
                                        width: 200,
                                        height: 200,
                                        child: Center(child: CircularProgressIndicator()),
                                      );
                                    },
                                  ),
                                ),
                              )
                            else
                              Text(msg['text'], style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
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
                IconButton(icon: const Icon(Icons.send, color: Colors.indigo), onPressed: sendMessage),
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
