import '../entities/app_notification.dart';

abstract interface class NotificationRepository {
  Future<List<AppNotification>> getNotifications();

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead();
}
