import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/repositories/repositories.dart';

/// Runs a save and, if it fails, tells the person why instead of leaving a
/// button that does nothing. Returns true when the write went through, so the
/// caller can decide whether to close the form.
Future<bool> guardedWrite(BuildContext context, Future<void> Function() write) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await write();
    return true;
  } on BookingException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } on BusUnavailableException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
  } on FirebaseException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(_messageFor(e))));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text("That didn't save. Please try again.")));
  }
  return false;
}

String _messageFor(FirebaseException e) => switch (e.code) {
      'permission-denied' => "You don't have permission to make that change.",
      'unavailable' || 'deadline-exceeded' => 'No internet connection. Check your connection and try again.',
      _ => "That didn't save. Please try again.",
    };
