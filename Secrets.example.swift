// Copy this file to Pavement/Config/Secrets.swift and fill in your own Supabase project values
// (Supabase dashboard → Project Settings → API). That file is gitignored.
//
// Use the publishable (anon) key only. Never put the service_role / secret key in the app.

import Foundation

enum Secrets {
    static let supabaseURL = URL(string: "https://YOUR-PROJECT-REF.supabase.co")!
    static let supabasePublishableKey = "sb_publishable_..."
}
