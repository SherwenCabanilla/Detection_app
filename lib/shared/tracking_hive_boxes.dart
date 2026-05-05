/// Hive box names for tracking data, scoped by Firebase user id so multiple
/// farmer accounts on one phone do not share cached group names or selection.
class TrackingHiveBoxes {
  TrackingHiveBoxes._();

  static String groupsBoxName(String? userId) {
    final u = (userId ?? '').trim();
    if (u.isEmpty) return 'trackingGroupsBox__guest';
    return 'trackingGroupsBox_$u';
  }

  static String sessionCacheBoxName(String? userId) {
    final u = (userId ?? '').trim();
    if (u.isEmpty) return 'trackingBox__guest';
    return 'trackingBox_$u';
  }

  /// Legacy global boxes (pre per-user isolation). Safe to delete on logout.
  static const List<String> legacyBoxNames = [
    'trackingGroupsBox',
    'trackingBox',
  ];
}
