package co.displaydeck.player

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import android.view.View
import android.widget.TextView
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : AppCompatActivity() {
  private lateinit var titleText: TextView
  private lateinit var subtitleText: TextView
  private lateinit var codeContainer: View
  private lateinit var webView: WebView

  private val handler = Handler(Looper.getMainLooper())
  private var stopped = false
  private val pollIntervalMs = 3_000L
  private val heartbeatIntervalMs = 30_000L

  private var currentContentKey: String? = null
  private var campaignStepRunnable: Runnable? = null

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    // Extra fallback for devices that re-show status/navigation bars.
    window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
    supportActionBar?.hide()
    setContentView(R.layout.activity_main)
    titleText = findViewById(R.id.titleText)
    subtitleText = findViewById(R.id.subtitleText)
    codeContainer = findViewById(R.id.codeContainer)
    webView = findViewById(R.id.webView)

    webView.settings.javaScriptEnabled = true
    webView.settings.domStorageEnabled = true
    webView.settings.mediaPlaybackRequiresUserGesture = false
    webView.isVerticalScrollBarEnabled = false
    webView.isHorizontalScrollBarEnabled = false
    webView.webViewClient = WebViewClient()

    enterImmersive()
  }

  override fun onWindowFocusChanged(hasFocus: Boolean) {
    super.onWindowFocusChanged(hasFocus)
    if (hasFocus) enterImmersive()
  }

  override fun onResume() {
    super.onResume()
    stopped = false
    enterImmersive()

    val existingCode = SettingsStore.getPairingCode(this).trim()
    val existingName = SettingsStore.getPairedDisplayName(this).trim()

    if (existingCode.isNotBlank() && existingName.isNotBlank()) {
      // Paired: start heartbeat immediately.
      showPaired(existingName)
      startHeartbeat(existingCode)
      return
    }

    if (existingCode.isNotBlank()) {
      // Has a code already, but not yet paired.
      showCode(existingCode)
      startPolling(existingCode)
      return
    }

    // First launch: request a pairing code from the API.
    showLoading()
    Thread {
      try {
        val hardwareId = SettingsStore.getOrCreateHardwareId(this)
        val code = requestPairingCode(hardwareId)
        SettingsStore.setPairingCode(this, code)
        runOnUiThread {
          if (stopped) return@runOnUiThread
          showCode(code)
          startPolling(code)
        }
      } catch (_: Exception) {
        // No UI message: keep screen minimal and retry.
        handler.postDelayed({
          if (!stopped) onResume()
        }, 5_000L)
      }
    }.start()
  }

  override fun onPause() {
    super.onPause()
    stopped = true
    handler.removeCallbacksAndMessages(null)
  }

  private fun enterImmersive() {
    WindowCompat.setDecorFitsSystemWindows(window, false)
    val controller = WindowInsetsControllerCompat(window, window.decorView)
    controller.hide(WindowInsetsCompat.Type.statusBars() or WindowInsetsCompat.Type.navigationBars())
    // Sticky immersive: bars can appear transiently by swipe, then auto-hide.
    controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
  }

  private fun stopCampaignPlayback() {
    val r = campaignStepRunnable
    if (r != null) handler.removeCallbacks(r)
    campaignStepRunnable = null
  }

  private fun showLoading() {
    currentContentKey = null
    stopCampaignPlayback()
    webView.visibility = View.GONE
    codeContainer.visibility = View.VISIBLE
    titleText.text = ""
    subtitleText.visibility = View.GONE
  }

  private fun showCode(code: String) {
    currentContentKey = null
    stopCampaignPlayback()
    webView.visibility = View.GONE
    codeContainer.visibility = View.VISIBLE
    titleText.text = code
    subtitleText.visibility = View.GONE
  }

  private fun showPaired(name: String) {
    currentContentKey = null
    stopCampaignPlayback()
    webView.visibility = View.GONE
    codeContainer.visibility = View.VISIBLE
    titleText.text = name
    subtitleText.visibility = View.GONE
  }

  private fun showNoContent(name: String?) {
    currentContentKey = null
    stopCampaignPlayback()
    webView.visibility = View.GONE
    codeContainer.visibility = View.VISIBLE
    titleText.text = name?.takeIf { it.isNotBlank() } ?: "No content"
    subtitleText.text = "Assign a menu on the dashboard"
    subtitleText.visibility = View.VISIBLE
  }

  private fun showNoCampaignContent(name: String?) {
    currentContentKey = null
    stopCampaignPlayback()
    webView.visibility = View.GONE
    codeContainer.visibility = View.VISIBLE
    titleText.text = name?.takeIf { it.isNotBlank() } ?: "No content"
    subtitleText.text = "Assign a campaign on the dashboard"
    subtitleText.visibility = View.VISIBLE
  }

  private fun showMenu(publicToken: String) {
    val url = "${SettingsStore.PUBLIC_BASE_URL}/display/menu/$publicToken"
    val key = "menu:$publicToken"
    if (currentContentKey == key && webView.visibility == View.VISIBLE) return

    currentContentKey = key
    stopCampaignPlayback()
    codeContainer.visibility = View.GONE
    webView.visibility = View.VISIBLE
    webView.loadUrl(url)
  }

  private data class CampaignItem(
    val type: String,
    val displayOrder: Int,
    val durationSec: Int,
    val menuPublicToken: String?,
    val downloadUrl: String?,
    val fileType: String?
  )

  private data class CampaignManifest(val campaignId: Int, val items: List<CampaignItem>)

  private fun showCampaign(campaignId: Int, displayName: String?) {
    val key = "campaign:$campaignId"
    if (currentContentKey == key && webView.visibility == View.VISIBLE) return

    currentContentKey = key
    stopCampaignPlayback()
    codeContainer.visibility = View.GONE
    webView.visibility = View.VISIBLE

    Thread {
      try {
        val hardwareId = SettingsStore.getOrCreateHardwareId(this)
        val provisioningToken = SettingsStore.getPairingCode(this).trim()
        val manifest = getCampaignManifest(hardwareId = hardwareId, provisioningToken = provisioningToken, campaignId = campaignId)
        val items = manifest.items.sortedWith(compareBy<CampaignItem> { it.displayOrder })
        runOnUiThread {
          if (stopped) return@runOnUiThread
          if (currentContentKey != key) return@runOnUiThread
          if (items.isEmpty()) showNoCampaignContent(displayName) else startCampaignPlayback(items)
        }
      } catch (_: Exception) {
        runOnUiThread {
          if (!stopped && currentContentKey == key) showNoCampaignContent(displayName)
        }
      }
    }.start()
  }

  private fun startCampaignPlayback(items: List<CampaignItem>) {
    stopCampaignPlayback()
    var idx = 0
    val runnable = object : Runnable {
      override fun run() {
        if (stopped) return
        if (items.isEmpty()) return

        val it = items[idx % items.size]
        idx++

        when (it.type.lowercase()) {
          "menu" -> {
            val tok = it.menuPublicToken
            if (!tok.isNullOrBlank()) {
              val url = "${SettingsStore.PUBLIC_BASE_URL}/display/menu/$tok"
              webView.loadUrl(url)
            }
          }
          else -> {
            val url = it.downloadUrl
            if (!url.isNullOrBlank()) {
              val ft = (it.fileType ?: "").lowercase()
              val html = if (ft.startsWith("video/")) {
                """
                  <!doctype html>
                  <html>
                    <head>
                      <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />
                      <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}video{width:100%;height:100%;object-fit:cover}</style>
                    </head>
                    <body>
                      <video autoplay muted playsinline loop src=\"$url\"></video>
                    </body>
                  </html>
                """.trimIndent()
              } else {
                """
                  <!doctype html>
                  <html>
                    <head>
                      <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />
                      <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}img{width:100%;height:100%;object-fit:cover}</style>
                    </head>
                    <body>
                      <img src=\"$url\" />
                    </body>
                  </html>
                """.trimIndent()
              }
              webView.loadDataWithBaseURL(url, html, "text/html", "utf-8", null)
            }
          }
        }

        val d = (if (it.durationSec > 0) it.durationSec else 10).toLong() * 1000L
        handler.postDelayed(this, d.coerceAtLeast(3_000L))
      }
    }

    campaignStepRunnable = runnable
    handler.post(runnable)
  }

  private fun startPolling(code: String) {
    handler.post(object : Runnable {
      override fun run() {
        if (stopped) return
        Thread {
          try {
            val hardwareId = SettingsStore.getOrCreateHardwareId(this@MainActivity)
            val status = getPairingStatus(hardwareId, code)
            val displayName = status.displayName
            if (status.claimed && !displayName.isNullOrBlank()) {
              SettingsStore.setPairedDisplayName(this@MainActivity, displayName)
              runOnUiThread {
                if (stopped) return@runOnUiThread
                showPaired(displayName)
                startHeartbeat(code)
              }
              return@Thread
            }
          } catch (e: Exception) {
            // If token is invalid/expired/claimed for someone else, restart pairing.
            val msg = e.message ?: ""
            if (msg.contains("HTTP 404") || msg.contains("HTTP 410") || msg.contains("HTTP 409")) {
              SettingsStore.clearPairingCode(this@MainActivity)
              SettingsStore.setPairedDisplayName(this@MainActivity, "")
              runOnUiThread {
                if (!stopped) onResume()
              }
              return@Thread
            }
          }
          handler.postDelayed(this, pollIntervalMs)
        }.start()
      }
    })
  }

  private fun startHeartbeat(code: String) {
    handler.post(object : Runnable {
      override fun run() {
        if (stopped) return
        Thread {
          try {
            val hardwareId = SettingsStore.getOrCreateHardwareId(this@MainActivity)
            val appVersion = BuildConfig.VERSION_NAME
            val deviceInfo = JSONObject()
              .put("manufacturer", android.os.Build.MANUFACTURER)
              .put("model", android.os.Build.MODEL)
              .put("device", android.os.Build.DEVICE)
              .put("product", android.os.Build.PRODUCT)
              .put("sdkInt", android.os.Build.VERSION.SDK_INT)
              .put("release", android.os.Build.VERSION.RELEASE)

            val hb = sendHeartbeat(hardwareId = hardwareId, provisioningToken = code, appVersion = appVersion, deviceInfo = deviceInfo)
            val displayName = hb.displayName
            if (!displayName.isNullOrBlank()) {
              SettingsStore.setPairedDisplayName(this@MainActivity, displayName)
            }

            runOnUiThread {
              if (stopped) return@runOnUiThread
              when (hb.assignmentType) {
                "menu" -> {
                  val token = hb.menuPublicToken
                  if (!token.isNullOrBlank()) showMenu(token) else showNoContent(displayName)
                }
                "campaign" -> {
                  val cid = hb.campaignId
                  if (cid != null && cid > 0) showCampaign(cid, displayName) else showNoCampaignContent(displayName)
                }
                else -> showNoContent(displayName)
              }
            }
          } catch (e: Exception) {
            // If token is no longer valid, clear and restart pairing.
            val msg = e.message ?: ""
            if (msg.contains("HTTP 404") || msg.contains("HTTP 410") || msg.contains("HTTP 409")) {
              SettingsStore.clearPairingCode(this@MainActivity)
              SettingsStore.setPairedDisplayName(this@MainActivity, "")
              runOnUiThread {
                if (!stopped) onResume()
              }
              return@Thread
            }
          }
          handler.postDelayed(this, heartbeatIntervalMs)
        }.start()
      }
    })
  }

  private data class PairingStatus(val claimed: Boolean, val displayName: String?)

  private data class HeartbeatStatus(
    val displayName: String?,
    val assignmentType: String,
    val menuPublicToken: String?,
    val campaignId: Int?
  )

  private fun requestPairingCode(hardwareId: String): String {
    val url = URL("${SettingsStore.API_BASE_URL}/device/provisioning/token")
    val body = JSONObject().put("HardwareId", hardwareId)
    val resp = postJson(url, body)
    val obj = JSONObject(resp)
    val code = obj.optString("PairingCode").ifBlank { obj.optString("ProvisioningToken") }
    if (code.isBlank()) throw IllegalStateException("Missing PairingCode")
    return code.trim().uppercase()
  }

  private fun getPairingStatus(hardwareId: String, code: String): PairingStatus {
    val url = URL("${SettingsStore.API_BASE_URL}/device/provisioning/status")
    val body = JSONObject()
      .put("HardwareId", hardwareId)
      .put("ProvisioningToken", code)
    val resp = postJson(url, body)
    val obj = JSONObject(resp)
    val claimed = obj.optBoolean("Claimed", false)
    val displayObj = obj.optJSONObject("Display")
    val name = displayObj?.optString("Name")
    return PairingStatus(claimed = claimed, displayName = name)
  }

  private fun sendHeartbeat(hardwareId: String, provisioningToken: String, appVersion: String, deviceInfo: JSONObject): HeartbeatStatus {
    val url = URL("${SettingsStore.API_BASE_URL}/device/heartbeat")
    val body = JSONObject()
      .put("HardwareId", hardwareId)
      .put("ProvisioningToken", provisioningToken)
      .put("AppVersion", appVersion)
      .put("DeviceInfo", deviceInfo)
    val resp = postJson(url, body)
    val obj = JSONObject(resp)
    val displayObj = obj.optJSONObject("Display")
    val displayName = displayObj?.optString("Name")
    val assignmentObj = obj.optJSONObject("Assignment")
    val type = assignmentObj?.optString("Type") ?: "none"
    val menuToken = assignmentObj?.optString("MenuPublicToken")?.takeIf { it.isNotBlank() }
    val campaignId = if (assignmentObj?.has("CampaignId") == true && !assignmentObj.isNull("CampaignId")) assignmentObj.optInt("CampaignId") else null
    return HeartbeatStatus(displayName = displayName, assignmentType = type, menuPublicToken = menuToken, campaignId = campaignId)
  }

  private fun getCampaignManifest(hardwareId: String, provisioningToken: String, campaignId: Int): CampaignManifest {
    val url = URL("${SettingsStore.API_BASE_URL}/device/campaign/manifest")
    val body = JSONObject()
      .put("HardwareId", hardwareId)
      .put("ProvisioningToken", provisioningToken)
      .put("CampaignId", campaignId)
    val resp = postJson(url, body)
    val obj = JSONObject(resp)
    val outCampaignId = obj.optInt("CampaignId", campaignId)
    val arr = obj.optJSONArray("Items")
    val items = mutableListOf<CampaignItem>()
    if (arr != null) {
      for (i in 0 until arr.length()) {
        val it = arr.optJSONObject(i) ?: continue
        items.add(
          CampaignItem(
            type = it.optString("Type", "media"),
            displayOrder = it.optInt("DisplayOrder", 0),
            durationSec = it.optInt("Duration", 10),
            menuPublicToken = it.optString("MenuPublicToken").takeIf { s -> s.isNotBlank() },
            downloadUrl = it.optString("DownloadUrl").takeIf { s -> s.isNotBlank() },
            fileType = it.optString("FileType").takeIf { s -> s.isNotBlank() }
          )
        )
      }
    }
    return CampaignManifest(campaignId = outCampaignId, items = items)
  }

  private fun postJson(url: URL, body: JSONObject): String {
    val conn = (url.openConnection() as HttpURLConnection)
    conn.requestMethod = "POST"
    conn.connectTimeout = 8_000
    conn.readTimeout = 8_000
    conn.doOutput = true
    conn.setRequestProperty("Content-Type", "application/json")
    conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }

    val httpCode = conn.responseCode
    val stream = if (httpCode in 200..299) conn.inputStream else conn.errorStream
    val text = BufferedReader(InputStreamReader(stream)).use { it.readText() }
    if (httpCode !in 200..299) throw IllegalStateException("HTTP $httpCode: $text")
    return text
  }
}
