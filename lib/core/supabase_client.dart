import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase'ди ишке киргизүү жана глобалдык клиентке кирүү.
class SupabaseInit {
  SupabaseInit._();

  static const String supabaseUrl     = 'https://sryacpgskdazcjrpamuc.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_YBnd957BckZUaYP90KSKpw_aHYklila';

  static Future<void> init() async {
    await Supabase.initialize(
      url:     supabaseUrl,
      anonKey: supabaseAnonKey, // ✅ ОҢДОО: publishableKey → anonKey
    );
  }
}

/// Кыска жол менен Supabase клиентине кирүү
final SupabaseClient supabase = Supabase.instance.client;