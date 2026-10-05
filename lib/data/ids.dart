int _counter = 0;

/// Client-side id for records created in the mock backend. Firestore's
/// auto-ids replace this in Stage 2; callers only ever treat ids as opaque.
String newId(String prefix) {
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return '$prefix-$stamp${(_counter++).toRadixString(36)}';
}
