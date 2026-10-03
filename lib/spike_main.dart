import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'spike/spike_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } on Exception {
    // CONVEX_URL can still come from --dart-define.
  }
  runApp(const SpikeApp());
}
