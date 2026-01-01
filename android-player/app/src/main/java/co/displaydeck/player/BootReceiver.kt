package co.displaydeck.player

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

    val launchIntent = Intent(context, MainActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    try {
      context.startActivity(launchIntent)
    } catch (_: Exception) {
      // Some OEM builds restrict activity launches at boot.
      // In that case, the user may need to allow "auto-start" for the app.
    }
  }
}
