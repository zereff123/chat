import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Thêm import

class Message {
  final String id;
  final String text;
  final String? imageUrl; // ✅ Sửa thành nullable
  final String senderId;
  final Timestamp? timestamp; // ✅ Sửa thành nullable
  final bool isDeleted;
  final List<String> deletedFor;

  Message({
    required this.id,
    required this.text,
    this.imageUrl,
    required this.senderId,
    this.timestamp,
    this.isDeleted = false,
    this.deletedFor = const [],
  });

  factory Message.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      senderId: data['senderId'] ?? '',
      timestamp: data['timestamp'],
      isDeleted: data['isDeleted'] ?? false,
      deletedFor: List<String>.from(data['deletedFor'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'imageUrl': imageUrl,
      'senderId': senderId,
      'timestamp': timestamp,
      'isDeleted': isDeleted,
      'deletedFor': deletedFor,
    };
  }
}