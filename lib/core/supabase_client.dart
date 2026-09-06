import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Thin accessor around the singleton Supabase client set up in `main()`.
/// Keeps `Supabase.instance.client` out of feature code so the client
/// itself stays swappable (e.g. for tests) without touching call sites.
SupabaseClient get supabase => Supabase.instance.client;

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );
}
