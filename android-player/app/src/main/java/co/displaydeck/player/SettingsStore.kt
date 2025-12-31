package co.displaydeck.player

import android.content.Context
import java.util.UUID

object SettingsStore {
  private const val PREFS = "displaydeck_player"

  private const val KEY_HARDWARE_ID = "hardwareId"
  private const val KEY_PAIRING_CODE = "pairingCode"
  private const val KEY_PAIRED_DISPLAY_NAME = "pairedDisplayName"

  // Hardcoded online API endpoint for now; device has zero user input.
  const val API_BASE_URL: String = "https://api.displaydeck.co.za"

  // Public website host for rendering display pages (e.g. /display/menu/{token}).
  const val PUBLIC_BASE_URL: String = "https://displaydeck.co.za"

  fun getOrCreateHardwareId(ctx: Context): String {
    val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    val existing = prefs.getString(KEY_HARDWARE_ID, null)
    if (!existing.isNullOrBlank()) return existing
    val created = UUID.randomUUID().toString()
    prefs.edit().putString(KEY_HARDWARE_ID, created).apply()
    return created
  }

  fun getPairingCode(ctx: Context): String =
    ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_PAIRING_CODE, "") ?: ""

  fun setPairingCode(ctx: Context, value: String) {
    ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY_PAIRING_CODE, value.trim().uppercase()).apply()
  }

  fun clearPairingCode(ctx: Context) {
    ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY_PAIRING_CODE).apply()
  }

  fun getPairedDisplayName(ctx: Context): String =
    ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_PAIRED_DISPLAY_NAME, "") ?: ""

  fun setPairedDisplayName(ctx: Context, value: String) {
    ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY_PAIRED_DISPLAY_NAME, value).apply()
  }
}
