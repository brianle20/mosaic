import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mosaic/app/app.dart';
import 'package:mosaic/core/config/app_environment.dart';
import 'package:mosaic/core/config/supabase_config.dart';
import 'package:mosaic/data/supabase/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    final environment = AppEnvironment.fromMap(dotenv.env);
    final config = SupabaseConfig.fromEnvironment(environment);
    await SupabaseBootstrap.initialize(config);

    runApp(MosaicApp(environment: environment));
  } catch (error) {
    runApp(MosaicApp(startupError: error.toString()));
  }
}
