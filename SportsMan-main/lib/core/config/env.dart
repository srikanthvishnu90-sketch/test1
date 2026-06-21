/// Public client configuration, injected at build/run time via
/// `--dart-define-from-file=env.json` (see CLAUDE.md › Config).
///
/// These are PUBLIC, client-safe values only. The Supabase anon/publishable key
/// is meant to ship in the client (RLS protects the data). SECRETS — Supabase
/// service_role, the hCaptcha secret, Stripe secret, Resend key — must NEVER be
/// referenced here; they live server-side only.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const hcaptchaSiteKey = String.fromEnvironment('HCAPTCHA_SITE_KEY');
}
