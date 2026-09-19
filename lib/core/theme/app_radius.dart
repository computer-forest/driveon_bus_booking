import 'package:flutter/material.dart';

/// Design tokens — corner radius.
///
/// Deliberately restrained: one radius for interactive controls, one for
/// containers, one for small tags. Nothing in this system uses a fully
/// rounded "pill" shape by default — status tags are small rounded rects,
/// not pills, so they read as markers rather than decoration.
class AppRadius {
  AppRadius._();

  static const double control = 10;
  static const double container = 14;
  static const double tag = 6;
  static const double hero = 22;

  static BorderRadius get controlRadius => BorderRadius.circular(control);
  static BorderRadius get containerRadius => BorderRadius.circular(container);
  static BorderRadius get tagRadius => BorderRadius.circular(tag);
  static BorderRadius get heroRadius => BorderRadius.circular(hero);
}
