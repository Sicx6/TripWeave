import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String authErrorMessage(Object error) {
  final text = error.toString();
  return text.replaceFirst(RegExp(r'^(AuthException|Exception):\s*'), '');
}

void showAuthError(BuildContext context, AsyncValue<void> state) {
  if (state.hasError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(authErrorMessage(state.error!))),
    );
  }
}
