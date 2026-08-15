import Foundation
import Supabase

enum SupabaseProvider {
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://lexbvkrvgsaprrgijsrf.supabase.co")!,
        supabaseKey: "sb_publishable_g8_VCsQ6TkvjGIbKy3ylvQ_cqIt77tk"
    )
}
