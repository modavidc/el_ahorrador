import 'dart:async';

import 'package:flutter/material.dart';

/// Tracks ownership of the processing fallback dialog.
///
/// A missing [OverlayEntry] does not imply that a dialog is open. Keeping that
/// distinction prevents share completion during startup from popping the home
/// route and exposing the Activity's black background.
class LoadingDialogTracker {
  bool _visible = false;

  bool get visible => _visible;

  void show(Future<void> Function() openDialog) {
    if (_visible) return;
    _visible = true;
    unawaited(openDialog().whenComplete(() => _visible = false));
  }

  bool dismiss(BuildContext context) {
    if (!_visible) return false;
    _visible = false;
    Navigator.of(context, rootNavigator: true).pop();
    return true;
  }
}
