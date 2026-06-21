/// A small, UI-facing user model. Deliberately plain so the rest of the app
/// never depends on Supabase's `User` type — the auth backend stays swappable.
class AppUser {
  final String id;
  final String? email;

  /// 'searcher' | 'provider'. Sourced from auth user_metadata for now; once #19
  /// lands real data this should be read from the `profiles` table.
  final String role;
  final String? name;

  const AppUser({
    required this.id,
    this.email,
    required this.role,
    this.name,
  });
}
