import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/supabase_notification_repository.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return SupabaseNotificationRepository(Supabase.instance.client);
});

final notificationListProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) => ref.watch(notificationRepositoryProvider).getNotifications(),
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationListProvider).maybeWhen(
        data: (items) => items.where((item) => !item.isRead).length,
        orElse: () => 0,
      );
});

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, void>(
  NotificationController.new,
);

class NotificationController extends AsyncNotifier<void> {
  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<bool> markAsRead(String notificationId) =>
      _run(() => _repository.markAsRead(notificationId));

  Future<bool> markAllAsRead() => _run(_repository.markAllAsRead);

  Future<bool> _run(Future<void> Function() operation) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(operation);
    if (!state.hasError) ref.invalidate(notificationListProvider);
    return !state.hasError;
  }
}
