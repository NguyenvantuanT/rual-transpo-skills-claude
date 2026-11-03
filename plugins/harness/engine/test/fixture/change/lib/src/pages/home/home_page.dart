import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  void go(BuildContext context) => Navigator.push(context, route);

  Widget build(BuildContext context) {
    final user = maybeUser!;
    // TODO remove
    return ElevatedButton(onPressed: null, child: Text('Hello'));
  }

  final c = Color(0xFF000000);
  final q = Supabase.instance.client;
}
