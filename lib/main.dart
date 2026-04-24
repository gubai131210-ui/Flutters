import 'package:flutter/widgets.dart';

import 'app/senti_app.dart';
import 'app/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(const SentiApp());
}
