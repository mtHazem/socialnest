import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_service.dart';
import '../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: firebaseService.getUnreadNotificationCount(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final unreadCount = userData['unreadNotifications'] ?? 0;
                
                if (unreadCount > 0) {
                  return TextButton(
                    onPressed: () {
                      firebaseService.markAllNotificationsAsRead();
                    },
                    child: Text(
                      'Mark all read',
                      style: TextStyle(
                        color: const Color(0xFF7C3AED),
                        fontSize: 14,
                      ),
                    ),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firebaseService.getUserNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF7C3AED)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading notifications: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 80, color: Color(0xFF94A3B8)),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your notifications will appear here',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final notificationData = notification.data() as Map<String, dynamic>;
              final notificationModel = NotificationModel.fromMap(notificationData);

              return _buildNotificationItem(notificationModel, firebaseService);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification, FirebaseService firebaseService) {
    Color getNotificationColor(String type) {
      switch (type) {
        case 'friend_request':
          return const Color(0xFF7C3AED);
        case 'friend_accepted':
          return Colors.green;
        case 'post_like':
          return Colors.pink;
        case 'post_comment':
          return Colors.blue;
        default:
          return const Color(0xFF94A3B8);
      }
    }

    IconData getNotificationIcon(String type) {
      switch (type) {
        case 'friend_request':
          return Icons.person_add_rounded;
        case 'friend_accepted':
          return Icons.people_rounded;
        case 'post_like':
          return Icons.favorite_rounded;
        case 'post_comment':
          return Icons.chat_bubble_rounded;
        default:
          return Icons.notifications_rounded;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead 
            ? const Color(0xFF1E293B).withOpacity(0.5)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: !notification.isRead 
            ? Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (!notification.isRead) {
              firebaseService.markNotificationAsRead(notification.id);
            }
            // TODO: Handle notification tap (navigate to post, profile, etc.)
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: getNotificationColor(notification.type).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    getNotificationIcon(notification.type),
                    color: getNotificationColor(notification.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notification.timeAgo,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF7C3AED),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}