abstract final class AppConfig {
  static const supabaseUrl = 'https://piamkeixwnwpqdxlbkwo.supabase.co';
  static const supabaseAnonKey =
      'sb_publishable_uzh19ccyfLXy5PAV9XBOug_OFcrzqBs';

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
