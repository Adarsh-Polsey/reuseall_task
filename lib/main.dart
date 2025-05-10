import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:reuse_task/screens/job_route_screen.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(
    MaterialApp(debugShowCheckedModeBanner: false, home: JobRouteScreen()),
  );
}
