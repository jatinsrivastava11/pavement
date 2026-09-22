import Supabase

/// The app's single connection to the Pavement Supabase project.
let supabase = SupabaseClient(
    supabaseURL: Secrets.supabaseURL,
    supabaseKey: Secrets.supabasePublishableKey,
    options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
)
