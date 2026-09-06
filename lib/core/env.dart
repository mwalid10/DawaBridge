import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads Supabase credentials from `.env` (gitignored, see `.env.example`).
///
/// Loaded once in `main()` before `runApp`. Values are not committed —
/// each developer / CI environment supplies its own `.env`.
class Env {
  Env._();

  static String get supabaseUrl => dotenv.get('SUPABASE_URL');
  static String get supabaseAnonKey => dotenv.get('SUPABASE_ANON_KEY');
}
