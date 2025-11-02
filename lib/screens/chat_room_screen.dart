import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import model và widget mới
import '../models/message_model.dart';
import '../widgets/message_bubble.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String chatTitle;

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final user = FirebaseAuth.instance.currentUser!;
  late CollectionReference messagesCol;
  late DocumentReference chatDoc;

  @override
  void initState() {
    super.initState();
    messagesCol = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages');
    chatDoc = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

    // Đánh dấu đã đọc tin nhắn
    chatDoc.update({'unread.${user.uid}': 0});
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    await messagesCol.add({
      'text': text,
      'senderId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
      'deletedFor': [],
    });

    await chatDoc.update({
      'lastMessage': text,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatTitle),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesCol
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final message = Message.fromDoc(docs[index]);
                    
                    return MessageBubble(
                      message: message,
                      currentUserId: user.uid,
                      chatId: widget.chatId,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send),
                  color: Colors.indigo,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}