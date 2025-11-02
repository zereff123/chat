import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ✅ Xóa tin nhắn cho riêng bạn
  Future<void> deleteMessageForMe(String chatId, String messageId, String currentUserId) async {
    try {
      final docRef = _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        
        final data = snapshot.data()!;
        List<dynamic> deletedFor = List.from(data['deletedFor'] ?? []);
        
        if (!deletedFor.contains(currentUserId)) {
          deletedFor.add(currentUserId);
          transaction.update(docRef, {
            'deletedFor': deletedFor,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('❌ Lỗi xóa tin nhắn: $e');
      rethrow;
    }
  }

  // ✅ Thu hồi tin nhắn cho mọi người
  Future<void> deleteMessageForEveryone(String chatId, String messageId, String currentUserId) async {
    try {
      final docRef = _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);
      
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw Exception('Tin nhắn không tồn tại');
      }
      
      final data = docSnapshot.data()!;
      if (data['senderId'] != currentUserId) {
        throw Exception('Chỉ người gửi mới được thu hồi tin nhắn');
      }
      
      // Xóa ảnh khỏi storage nếu có
      if (data['imageUrl'] != null && data['imageUrl'].isNotEmpty) {
        await _deleteMessageImage(data['imageUrl']);
      }
      
      await docRef.update({
        'isDeleted': true,
        'deletedFor': ['all'],
        'deletedAt': FieldValue.serverTimestamp(),
        'originalText': data['text'],
        'text': 'Tin nhắn đã được thu hồi',
        'imageUrl': '',
      });
    } catch (e) {
      print('❌ Lỗi thu hồi tin nhắn: $e');
      rethrow;
    }
  }

  Future<void> _deleteMessageImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('⚠️ Lỗi xóa ảnh: $e');
    }
  }
}