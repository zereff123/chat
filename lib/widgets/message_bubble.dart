import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final String currentUserId;
  final String chatId;
  final MessageService messageService = MessageService();

  // ❌ XÓA CONST - sử dụng constructor thường
  MessageBubble({
    Key? key,
    required this.message,
    required this.currentUserId,
    required this.chatId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (_isMessageDeleted(message, currentUserId)) {
      return _buildDeletedMessage();
    }

    final isMe = message.senderId == currentUserId;

    return GestureDetector(
      onLongPress: () => _showDeleteOptions(context),
      child: Align(
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
              if (message.imageUrl != null && message.imageUrl!.isNotEmpty)
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: Image.network(message.imageUrl!),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      message.imageUrl!,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                          width: 200,
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                )
              else
                Text(
                  message.text,
                  style: const TextStyle(fontSize: 16),
                ),
              const SizedBox(height: 4),
              if (message.timestamp != null)
                Text(
                  _formatTime(message.timestamp!),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDeleteMenu(context),
    );
  }

  Widget _buildDeleteMenu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuTile(
              icon: Icons.delete_outline,
              title: 'Xóa cho tôi',
              color: Colors.grey,
              onTap: () {
                Navigator.pop(context);
                _deleteForMe(context);
              },
            ),
            
            if (message.senderId == currentUserId)
              _buildMenuTile(
                icon: Icons.delete_forever,
                title: 'Thu hồi cho mọi người',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteForEveryone(context);
                },
              ),
            
            _buildMenuTile(
              icon: Icons.cancel,
              title: 'Hủy',
              color: Colors.grey,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  void _deleteForMe(BuildContext context) async {
    try {
      await messageService.deleteMessageForMe(chatId, message.id, currentUserId);
      _showSnackBar(context, 'Đã xóa tin nhắn cho bạn');
    } catch (e) {
      _showSnackBar(context, 'Lỗi khi xóa tin nhắn: $e');
    }
  }

  void _confirmDeleteForEveryone(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Thu hồi tin nhắn?'),
        content: Text('Tin nhắn sẽ bị xóa cho tất cả mọi người. Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteForEveryone(context);
            },
            child: Text('Thu hồi', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteForEveryone(BuildContext context) async {
    try {
      await messageService.deleteMessageForEveryone(chatId, message.id, currentUserId);
      _showSnackBar(context, 'Đã thu hồi tin nhắn');
    } catch (e) {
      _showSnackBar(context, 'Lỗi khi thu hồi: $e');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildDeletedMessage() {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.grey, size: 16),
            SizedBox(width: 8),
            Text(
              'Tin nhắn đã được thu hồi',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isMessageDeleted(Message message, String currentUserId) {
    if (message.isDeleted || message.deletedFor.contains('all')) {
      return true;
    }
    if (message.deletedFor.contains(currentUserId)) {
      return true;
    }
    return false;
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}