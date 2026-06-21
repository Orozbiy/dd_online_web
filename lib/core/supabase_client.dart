import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase'ди ишке киргизүү жана глобалдык клиентке кирүү.
///
/// main.dart'та `await SupabaseInit.init();` чакырылат.
class SupabaseInit {
  SupabaseInit._();

  static const String supabaseUrl = 'https://sryacpgskdazcjrpamuc.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_YBnd957BckZUaYP90KSKpw_aHYklila';

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }
}

/// Кыска жол менен Supabase клиентине кирүү:
/// `supabase.from('products').select()`
final SupabaseClient supabase = Supabase.instance.client;
