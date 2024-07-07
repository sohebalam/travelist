import 'package:flutter/material.dart';

Widget buildErrorMessage(BuildContext context, errorMessage) {
  if (errorMessage != null) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        errorMessage!,
        style: const TextStyle(
          color: Colors.red,
        ),
      ),
    );
  } else {
    return const SizedBox.shrink();
  }
}
