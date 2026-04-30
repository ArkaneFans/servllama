import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:servllama/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ServLlamaApp());
}
