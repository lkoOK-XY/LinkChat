import 'package:flutter/material.dart';
import '../theme/colors.dart';

enum MessageOwner { self, other }

class MessageBubble extends StatelessWidget {
  final String content;
  final MessageOwner owner;
  final DateTime time;

  const MessageBubble({
    super.key,
    required this.content,
    required this.owner,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final isSelf = owner == MessageOwner.self;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isSelf
              ? AppColors.bubbleSelf
              : (isDark
                  ? AppColors.bubbleOtherDark
                  : AppColors.bubbleOtherLight),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isSelf ? 16 : 4),
            bottomRight: Radius.circular(isSelf ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 消息内容
            Text(
              content,
              style: TextStyle(
                color: isSelf ? Colors.white : null,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            // 时间戳
            Text(
              _formatTime(time),
              style: TextStyle(
                fontSize: 11,
                color: isSelf
                    ? Colors.white.withOpacity(0.7)
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (time.day == now.day && time.month == now.month && time.year == now.year) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${_getWeekDay(time.weekday)} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
    }
  }

  String _getWeekDay(int weekday) {
    switch (weekday) {
      case 1:
        return '周一';
      case 2:
        return '周二';
      case 3:
        return '周三';
      case 4:
        return '周四';
      case 5:
        return '周五';
      case 6:
        return '周六';
      case 7:
        return '周日';
      default:
        return '';
    }
  }
}
