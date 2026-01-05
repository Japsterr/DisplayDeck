package co.displaydeck.player

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.view.WindowManager
import android.view.View
import android.view.MotionEvent
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.AlphaAnimation
import android.view.animation.Animation
import android.view.animation.AnimationSet
import android.view.animation.ScaleAnimation
import android.view.animation.TranslateAnimation
import android.widget.FrameLayout
import android.widget.TextView
import android.util.Base64
import android.media.AudioManager
import android.content.Context
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceError
import android.webkit.WebResourceResponse
import android.webkit.RenderProcessGoneDetail
import android.webkit.JavascriptInterface
import android.webkit.SslErrorHandler
import android.net.http.SslError
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.PlaybackException
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.ByteArrayOutputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : AppCompatActivity() {
  private lateinit var titleText: TextView
  private lateinit var subtitleText: TextView
  private lateinit var codeContainer: View
  private lateinit var webView: WebView
  private lateinit var playerView: PlayerView
  private var player: ExoPlayer? = null
  private lateinit var debugOverlay: TextView
  private lateinit var versionOverlay: TextView
  private val overlayLines = ArrayDeque<String>()

  // Multi-zone layout support
  private lateinit var zoneContainer: FrameLayout
  private val zoneViews = mutableMapOf<String, View>()
  private var currentLayoutId: Int? = null

  // Touch interaction tracking
  private var touchStartTime: Long = 0
  private var touchStartX: Float = 0f
  private var touchStartY: Float = 0f

  // Transition effects
  private var currentTransitionType: String = "fade"
  private var transitionDurationMs: Long = 500

  // Remote command polling
  private val commandPollIntervalMs = 10_000L
  private var lastCommandId: Int = 0

  private val debugOverlayEnabled = false

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
    playerView = findViewById(R.id.playerView)
    webView = findViewById(R.id.webView)
    debugOverlay = findViewById(R.id.debugOverlay)
    versionOverlay = findViewById(R.id.versionOverlay)

    versionOverlay.text = "v${BuildConfig.VERSION_NAME}"

    // Initialize zone container for multi-zone layouts
    zoneContainer = findViewById(R.id.zoneContainer)

    webView.settings.javaScriptEnabled = true
    webView.settings.domStorageEnabled = true
    webView.settings.mediaPlaybackRequiresUserGesture = false
    webView.settings.loadsImagesAutomatically = true
    webView.settings.blockNetworkImage = false
    webView.settings.blockNetworkLoads = false
    webView.settings.useWideViewPort = true
    webView.settings.loadWithOverviewMode = true
    // Some Android WebViews block media if any asset chain is treated as mixed-content.
    webView.settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
    webView.isVerticalScrollBarEnabled = false
    webView.isHorizontalScrollBarEnabled = false
    webView.addJavascriptInterface(object {
      @JavascriptInterface
      fun onMediaLoaded() {
        // no-op (debug only)
      }

      @JavascriptInterface
      fun onMediaError(message: String?) {
        runOnUiThread {
          if (!stopped) {
            val msg = (message ?: "").take(400)
            showOverlay(if (msg.isBlank()) "Media error" else "Media error: $msg")
          }
        }
      }

      @JavascriptInterface
      fun onJsStatus(message: String?) {
        // no-op (debug only)
      }
    }, "DD")

    webView.webViewClient = object : WebViewClient() {
      override fun onPageFinished(view: WebView?, url: String?) {
        super.onPageFinished(view, url)
        // no-op (debug only)
      }

      override fun onRenderProcessGone(view: WebView?, detail: RenderProcessGoneDetail?): Boolean {
        val didCrash = detail?.didCrash() ?: false
        val prio = detail?.rendererPriorityAtExit() ?: -1
        showOverlay("WebView renderer gone (crash=$didCrash prio=$prio)")
        // Returning true means we handled it (prevents app crash).
        return true
      }

      override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
        super.onReceivedError(view, request, error)
        if (request?.isForMainFrame == true) {
          val desc = error?.description?.toString() ?: "Unknown error"
          loadCampaignMessageHtml("WebView error", desc)
        }
      }

      override fun onReceivedHttpError(view: WebView?, request: WebResourceRequest?, errorResponse: WebResourceResponse?) {
        super.onReceivedHttpError(view, request, errorResponse)
        if (request?.isForMainFrame == true) {
          val code = errorResponse?.statusCode ?: 0
          val reason = errorResponse?.reasonPhrase ?: ""
          loadCampaignMessageHtml("WebView HTTP error", "HTTP $code $reason")
        }
      }

      override fun onReceivedSslError(view: WebView?, handler: SslErrorHandler?, error: SslError?) {
        // Older Android TV boxes often have outdated trust stores; default behavior can look like a blank/black page.
        handler?.cancel()
        val primary = error?.primaryError ?: -1
        val url = error?.url ?: ""
        loadCampaignMessageHtml("WebView SSL error", "SSL error $primary\n$url")
      }
    }
    webView.webChromeClient = WebChromeClient()
    webView.setBackgroundColor(Color.BLACK)

    enterImmersive()
  }

  private fun normalizeMediaUrl(rawUrl: String): String {
    return try {
      val u = URL(rawUrl)
      val host = u.host ?: return rawUrl
      val port = u.port
      val isInternalMinio =
        host == "minio" ||
          host == "displaydeck-minio" ||
          (host == "localhost" && port == 9000) ||
          (host == "127.0.0.1" && port == 9000)

      if (!isInternalMinio) return rawUrl

      val path = u.path ?: ""
      val query = u.query?.takeIf { it.isNotBlank() }?.let { "?$it" } ?: ""
      "${SettingsStore.PUBLIC_BASE_URL}/minio$path$query"
    } catch (_: Exception) {
      rawUrl
    }
  }

  private fun showOverlay(msg: String) {
    if (!debugOverlayEnabled && !msg.startsWith("WebView renderer gone") && !msg.startsWith("WebView error") && !msg.startsWith("WebView HTTP error") && !msg.startsWith("Media fetch failed") && !msg.startsWith("Media error")) {
      return
    }
    val safe = msg.replace("\r", " ").trim()
    if (safe.isBlank()) return
    overlayLines.addLast(safe)
    while (overlayLines.size > 6) overlayLines.removeFirst()
    debugOverlay.text = overlayLines.joinToString("\n")
    debugOverlay.visibility = View.VISIBLE
  }

  private fun hideOverlay() {
    debugOverlay.visibility = View.GONE
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

    // Stop native video playback when backgrounded.
    stopVideo()
  }

  override fun onDestroy() {
    super.onDestroy()
    releasePlayer()
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
    playerView.visibility = View.GONE
    hideOverlay()
    codeContainer.visibility = View.VISIBLE
    titleText.text = ""
    subtitleText.visibility = View.GONE
  }

  private fun showCode(code: String) {
    currentContentKey = null
    stopCampaignPlayback()
    webView.visibility = View.GONE
    playerView.visibility = View.GONE
    hideOverlay()
    codeContainer.visibility = View.VISIBLE
    titleText.text = code
    subtitleText.visibility = View.GONE
  }

  private fun showPaired(name: String) {
    currentContentKey = null
    stopCampaignPlayback()
    webView.visibility = View.GONE
    playerView.visibility = View.GONE
    hideOverlay()
    codeContainer.visibility = View.VISIBLE
    titleText.text = name
    subtitleText.visibility = View.GONE
  }

  private fun showNoContent(name: String?) {
    currentContentKey = null
    stopCampaignPlayback()
    webView.visibility = View.GONE
    playerView.visibility = View.GONE
    hideOverlay()
    codeContainer.visibility = View.VISIBLE
    titleText.text = name?.takeIf { it.isNotBlank() } ?: "Waiting for content"
    subtitleText.text = "No menu/campaign/infoboard assigned"
    subtitleText.visibility = View.VISIBLE
  }

  private fun showNoCampaignContent(name: String?) {
    currentContentKey = null
    stopCampaignPlayback()
    webView.visibility = View.GONE
    playerView.visibility = View.GONE
    hideOverlay()
    codeContainer.visibility = View.VISIBLE
    titleText.text = name?.takeIf { it.isNotBlank() } ?: "Waiting for content"
    subtitleText.text = "No menu/campaign/infoboard assigned"
    subtitleText.visibility = View.VISIBLE
  }

  private fun showMenu(publicToken: String) {
    val url = "${SettingsStore.PUBLIC_BASE_URL}/display/menu-ssr/$publicToken"
    val key = "menu:$publicToken"
    if (currentContentKey == key && webView.visibility == View.VISIBLE) return

    currentContentKey = key
    stopCampaignPlayback()
    stopVideo()
    codeContainer.visibility = View.GONE
    playerView.visibility = View.GONE
    webView.visibility = View.VISIBLE
    hideOverlay()
    webView.loadUrl(url)
  }

  private fun showInfoBoard(publicToken: String) {
    val url = "${SettingsStore.PUBLIC_BASE_URL}/display/infoboard-ssr/$publicToken"
    val key = "infoboard:$publicToken"
    if (currentContentKey == key && webView.visibility == View.VISIBLE) return

    currentContentKey = key
    stopCampaignPlayback()
    stopVideo()
    codeContainer.visibility = View.GONE
    playerView.visibility = View.GONE
    webView.visibility = View.VISIBLE
    hideOverlay()
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
    stopVideo()
    codeContainer.visibility = View.GONE
    playerView.visibility = View.GONE
    webView.visibility = View.VISIBLE
    hideOverlay()

    Thread {
      try {
        val hardwareId = SettingsStore.getOrCreateHardwareId(this)
        val provisioningToken = SettingsStore.getPairingCode(this).trim()
        val manifest = getCampaignManifest(hardwareId = hardwareId, provisioningToken = provisioningToken, campaignId = campaignId)
        val items = manifest.items.sortedWith(compareBy<CampaignItem> { it.displayOrder })
        runOnUiThread {
          if (stopped) return@runOnUiThread
          if (currentContentKey != key) return@runOnUiThread
          if (items.isEmpty()) {
            showNoCampaignContent(displayName)
          } else {
            startCampaignPlayback(items)
          }
        }
      } catch (_: Exception) {
        runOnUiThread {
          if (!stopped && currentContentKey == key) {
            showNoCampaignContent(displayName)
          }
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
              val url = "${SettingsStore.PUBLIC_BASE_URL}/display/menu-ssr/$tok"
              hideOverlay()
              stopVideo()
              playerView.visibility = View.GONE
              webView.visibility = View.VISIBLE
              webView.loadUrl(url)
            } else {
              loadCampaignMessageHtml("Campaign item error", "Menu item is missing MenuPublicToken")
            }
          }
          else -> {
            val url = it.downloadUrl
            if (url.isNullOrBlank()) {
              loadCampaignMessageHtml("Campaign item error", "Media item is missing DownloadUrl")
            } else {
              val declaredType = (it.fileType ?: "").lowercase()
              probeThenLoadMedia(url = url, declaredType = declaredType)
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

  private fun loadCampaignMessageHtml(title: String, message: String) {
    val safeTitle = title.replace("<", "&lt;").replace(">", "&gt;")
    val safeMessage = message.replace("<", "&lt;").replace(">", "&gt;")
    val html = """
      <!doctype html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
          <style>
            html,body{margin:0;height:100%;background:#000;display:flex;align-items:center;justify-content:center}
            .box{max-width:92vw;color:#fff;font:14px/1.3 monospace;white-space:pre-wrap;opacity:.95}
            .t{font-weight:700;margin-bottom:10px}
            .m{opacity:.9}
          </style>
        </head>
        <body>
          <div class="box">
            <div class="t">$safeTitle</div>
            <div class="m">$safeMessage</div>
          </div>
        </body>
      </html>
    """.trimIndent()
    webView.loadDataWithBaseURL("${SettingsStore.PUBLIC_BASE_URL}/", html, "text/html", "utf-8", null)
  }

  private data class UrlProbeResult(
    val ok: Boolean,
    val httpCode: Int,
    val contentType: String,
    val errorSnippet: String?
  )

  private fun probeThenLoadMedia(url: String, declaredType: String) {
    val normalizedUrl = normalizeMediaUrl(url)

    // Images: render via HTML wrapper with CSS cover (no JS).
    if (declaredType.startsWith("image/")) {
      hideOverlay()
      Thread {
        val probe = probeUrl(normalizedUrl)
        runOnUiThread {
          if (stopped) return@runOnUiThread

          if (!probe.ok) {
            val extra = probe.errorSnippet?.takeIf { it.isNotBlank() }?.let { "\n\n$it" } ?: ""
            loadCampaignMessageHtml(
              "Media fetch failed",
              "HTTP ${probe.httpCode}\n${probe.contentType.ifBlank { "(no content-type)" }}\n$normalizedUrl$extra"
            )
            return@runOnUiThread
          }

          stopVideo()
          playerView.visibility = View.GONE
          webView.visibility = View.VISIBLE
          hideOverlay()
          loadCoverImageHtml(normalizedUrl)
        }
      }.start()
      return
    }

    // Videos: use native ExoPlayer.
    if (declaredType.startsWith("video/")) {
      webView.visibility = View.GONE
      playerView.visibility = View.VISIBLE
      hideOverlay()
      playVideo(normalizedUrl)
      return
    }

    // For other media (e.g., video), do a quick probe so failures are explicit.
    hideOverlay()

    Thread {
      val probe = probeUrl(normalizedUrl)
      runOnUiThread {
        if (stopped) return@runOnUiThread

        if (!probe.ok) {
          val extra = probe.errorSnippet?.takeIf { it.isNotBlank() }?.let { "\n\n$it" } ?: ""
          loadCampaignMessageHtml(
            "Media fetch failed",
            "HTTP ${probe.httpCode}\n${probe.contentType.ifBlank { "(no content-type)" }}\n$normalizedUrl$extra"
          )
          return@runOnUiThread
        }

        val effectiveType = when {
          declaredType.isNotBlank() -> declaredType
          probe.contentType.isNotBlank() -> probe.contentType.lowercase()
          else -> ""
        }

        // If server didn't send a type but it looks like video, use native player anyway.
        if (effectiveType.startsWith("video/")) {
          webView.visibility = View.GONE
          playerView.visibility = View.VISIBLE
          playVideo(normalizedUrl)
          return@runOnUiThread
        }

        // Images are handled above; this path is for non-image/non-video.

        val urlB64 = Base64.encodeToString(normalizedUrl.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
        val html = if (effectiveType.startsWith("video/")) {
          """
            <!doctype html>
            <html>
              <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0" />
                <style>
                  html,body{margin:0;height:100%;background:#000;overflow:hidden}
                  video{width:100%;height:100%;object-fit:cover}
                  #err{position:fixed;left:8px;top:8px;right:8px;color:#fff;font:12px/1.2 monospace;opacity:.9;display:none;white-space:pre-wrap}
                </style>
              </head>
              <body>
                <div id="err"></div>
                <video id="m" autoplay muted playsinline loop></video>
                <script>
                  (function(){
                    var v = document.getElementById('m');
                    var err = document.getElementById('err');
                    function show(msg){ err.style.display='block'; err.textContent = msg; }
                    function hide(){ err.style.display='none'; }
                    hide();

                    try { if (window.DD && DD.onJsStatus) DD.onJsStatus('started'); } catch (e) {}

                    var u = '';
                    try { u = atob('$urlB64'); } catch (e) { show('Video URL decode failed\n' + e); return; }

                    try { if (window.DD && DD.onJsStatus) DD.onJsStatus('url decoded'); } catch (e) {}

                    var t = setTimeout(function(){ show('Video load timed out\n' + u); }, 8000);
                    v.onloadeddata = function(){ clearTimeout(t); hide(); if (window.DD && DD.onMediaLoaded) DD.onMediaLoaded(); };
                    v.onerror = function(){ clearTimeout(t); show('Video failed to load\n' + u); if (window.DD && DD.onMediaError) DD.onMediaError('video failed'); };
                    v.src = u;

                    try { if (window.DD && DD.onJsStatus) DD.onJsStatus('src set'); } catch (e) {}
                    var p = v.play();
                    if (p && p.catch) p.catch(function(e){ clearTimeout(t); show('Video play blocked\n' + e + '\n' + u); if (window.DD && DD.onMediaError) DD.onMediaError('video play blocked'); });
                  })();
                </script>
              </body>
            </html>
          """.trimIndent()
        } else {
          """
            <!doctype html>
            <html>
              <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0" />
                <style>
                  html,body{margin:0;height:100%;background:#000;overflow:hidden}
                  img{width:100%;height:100%;object-fit:cover}
                  #err{position:fixed;left:8px;top:8px;right:8px;color:#fff;font:12px/1.2 monospace;opacity:.9;display:block;white-space:pre-wrap}
                </style>
              </head>
              <body>
                <div id="err">Loading image…</div>
                <img id="m" />
                <script>
                  (function(){
                    var img = document.getElementById('m');
                    var err = document.getElementById('err');
                    function show(msg){ err.style.display='block'; err.textContent = msg; }
                    function hide(){ err.style.display='none'; }
                    show('Loading image…');

                    try { if (window.DD && DD.onJsStatus) DD.onJsStatus('started'); } catch (e) {}

                    var u = '';
                    try { u = atob('$urlB64'); } catch (e) { show('Image URL decode failed\n' + e); return; }

                    try { if (window.DD && DD.onJsStatus) DD.onJsStatus('url decoded'); } catch (e) {}

                    var t = setTimeout(function(){ show('Image load timed out\n' + u); }, 8000);
                    img.onload = function(){ clearTimeout(t); hide(); if (window.DD && DD.onMediaLoaded) DD.onMediaLoaded(); };
                    img.onerror = function(){ clearTimeout(t); show('Image failed to load\n' + u); if (window.DD && DD.onMediaError) DD.onMediaError('image failed'); };
                    img.src = u;

                    try { if (window.DD && DD.onJsStatus) DD.onJsStatus('src set'); } catch (e) {}
                  })();
                </script>
              </body>
            </html>
          """.trimIndent()
        }

        webView.loadDataWithBaseURL("${SettingsStore.PUBLIC_BASE_URL}/", html, "text/html", "utf-8", null)
      }
    }.start()
  }

  private fun loadCoverImageHtml(url: String) {
    // HTML attribute escape so presigned URLs don't break the tag.
    val safeUrl = url
      .replace("&", "&amp;")
      .replace("\"", "&quot;")
      .replace("<", "&lt;")
      .replace(">", "&gt;")

    val html = """
      <!doctype html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
          <style>
            html,body{margin:0;height:100%;background:#000;overflow:hidden}
            img{width:100%;height:100%;object-fit:cover}
            #err{position:fixed;left:8px;top:8px;right:8px;color:#fff;font:12px/1.2 monospace;opacity:.9;display:none;white-space:pre-wrap}
          </style>
        </head>
        <body>
          <div id="err"></div>
          <img id="m" src="$safeUrl" />
          <script>
            (function(){
              var img = document.getElementById('m');
              var err = document.getElementById('err');
              function show(msg){ err.style.display='block'; err.textContent = msg; }
              function hide(){ err.style.display='none'; }
              hide();
              var t = setTimeout(function(){
                show('Image load timed out');
                try { if (window.DD && DD.onMediaError) DD.onMediaError('image timeout'); } catch (e) {}
              }, 8000);
              img.onload = function(){ clearTimeout(t); hide(); try { if (window.DD && DD.onMediaLoaded) DD.onMediaLoaded(); } catch (e) {} };
              img.onerror = function(){ clearTimeout(t); show('Image failed to load'); try { if (window.DD && DD.onMediaError) DD.onMediaError('image failed'); } catch (e) {} };
            })();
          </script>
        </body>
      </html>
    """.trimIndent()

    webView.loadDataWithBaseURL("${SettingsStore.PUBLIC_BASE_URL}/", html, "text/html", "utf-8", null)
  }

  private fun ensurePlayer(): ExoPlayer {
    val existing = player
    if (existing != null) return existing

    val created = ExoPlayer.Builder(this).build()
    created.repeatMode = Player.REPEAT_MODE_ONE
    created.addListener(object : Player.Listener {
      override fun onPlayerError(error: PlaybackException) {
        runOnUiThread {
          if (stopped) return@runOnUiThread
          showOverlay("Media error: ${error.errorCodeName}")
        }
      }
    })
    playerView.player = created
    player = created
    return created
  }

  private fun playVideo(url: String) {
    val p = ensurePlayer()
    val normalizedUrl = normalizeMediaUrl(url)
    p.setMediaItem(MediaItem.fromUri(normalizedUrl))
    p.prepare()
    p.playWhenReady = true
  }

  private fun stopVideo() {
    val p = player ?: return
    try {
      p.pause()
      p.stop()
      p.clearMediaItems()
    } catch (_: Exception) {
      // ignore
    }
  }

  private fun releasePlayer() {
    val p = player ?: return
    player = null
    try {
      p.release()
    } catch (_: Exception) {
      // ignore
    }
  }

  private fun probeUrl(url: String): UrlProbeResult {
    return try {
      val conn = (URL(url).openConnection() as HttpURLConnection)
      conn.instanceFollowRedirects = true
      conn.connectTimeout = 6_000
      conn.readTimeout = 6_000
      conn.requestMethod = "GET"
      conn.setRequestProperty("Range", "bytes=0-0")

      val code = conn.responseCode
      val ct = (conn.getHeaderField("Content-Type") ?: "").trim()
      val ok = code in 200..299 || code == 206

      val errSnippet = if (!ok) {
        try {
          val stream = conn.errorStream ?: conn.inputStream
          stream?.bufferedReader()?.use { it.readText().take(400) }
        } catch (_: Exception) {
          null
        }
      } else null

      UrlProbeResult(ok = ok, httpCode = code, contentType = ct, errorSnippet = errSnippet)
    } catch (e: Exception) {
      UrlProbeResult(ok = false, httpCode = 0, contentType = "", errorSnippet = e.toString())
    }
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
    // Start remote command polling
    startCommandPolling(code)

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

            // Update transition settings
            if (hb.transitionType != null) {
              currentTransitionType = hb.transitionType
            }
            if (hb.transitionDuration != null && hb.transitionDuration > 0) {
              transitionDurationMs = hb.transitionDuration.toLong()
            }

            runOnUiThread {
              if (stopped) return@runOnUiThread

              // Check for multi-zone layout first
              if (hb.layout != null && hb.layout.zones.isNotEmpty()) {
                showMultiZoneLayout(hb.layout)
                return@runOnUiThread
              }

              // Clear zone views if switching to single-content mode
              if (currentLayoutId != null) {
                clearZoneViews()
                zoneContainer.visibility = View.GONE
              }

              when (hb.assignmentType) {
                "menu" -> {
                  val token = hb.menuPublicToken
                  if (!token.isNullOrBlank()) showMenu(token) else showNoContent(displayName)
                }
                "campaign" -> {
                  val cid = hb.campaignId
                  if (cid != null && cid > 0) showCampaign(cid, displayName) else showNoCampaignContent(displayName)
                }
                "infoboard" -> {
                  val token = hb.infoBoardPublicToken
                  if (!token.isNullOrBlank()) showInfoBoard(token) else showNoContent(displayName)
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
    val campaignId: Int?,
    val infoBoardPublicToken: String?,
    val layout: LayoutConfig?,
    val transitionType: String?,
    val transitionDuration: Int?
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
    val infoBoardToken = assignmentObj?.optString("InfoBoardPublicToken")?.takeIf { it.isNotBlank() }

    // Parse layout for multi-zone support
    val layout = parseLayoutFromHeartbeat(assignmentObj)

    // Parse transition settings
    val transitionType = assignmentObj?.optString("TransitionType")?.takeIf { it.isNotBlank() }
    val transitionDuration = if (assignmentObj?.has("TransitionDuration") == true) assignmentObj.optInt("TransitionDuration") else null

    return HeartbeatStatus(
      displayName = displayName,
      assignmentType = type,
      menuPublicToken = menuToken,
      campaignId = campaignId,
      infoBoardPublicToken = infoBoardToken,
      layout = layout,
      transitionType = transitionType,
      transitionDuration = transitionDuration
    )
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

  // ===== MULTI-ZONE LAYOUT SUPPORT =====

  private data class ZoneConfig(
    val zoneName: String,
    val xPercent: Float,
    val yPercent: Float,
    val widthPercent: Float,
    val heightPercent: Float,
    val zIndex: Int,
    val contentType: String?,
    val contentUrl: String?,
    val menuPublicToken: String?,
    val campaignId: Int?
  )

  private data class LayoutConfig(
    val layoutId: Int,
    val layoutName: String,
    val zones: List<ZoneConfig>
  )

  private fun parseLayoutFromHeartbeat(assignmentObj: JSONObject?): LayoutConfig? {
    if (assignmentObj == null) return null
    val layoutObj = assignmentObj.optJSONObject("Layout") ?: return null
    val layoutId = layoutObj.optInt("Id", 0)
    if (layoutId == 0) return null

    val zonesArr = layoutObj.optJSONArray("Zones") ?: return null
    val zones = mutableListOf<ZoneConfig>()

    for (i in 0 until zonesArr.length()) {
      val z = zonesArr.optJSONObject(i) ?: continue
      zones.add(ZoneConfig(
        zoneName = z.optString("ZoneName", "zone$i"),
        xPercent = z.optDouble("XPercent", 0.0).toFloat(),
        yPercent = z.optDouble("YPercent", 0.0).toFloat(),
        widthPercent = z.optDouble("WidthPercent", 100.0).toFloat(),
        heightPercent = z.optDouble("HeightPercent", 100.0).toFloat(),
        zIndex = z.optInt("ZIndex", 0),
        contentType = z.optString("ContentType").takeIf { it.isNotBlank() },
        contentUrl = z.optString("ContentUrl").takeIf { it.isNotBlank() },
        menuPublicToken = z.optString("MenuPublicToken").takeIf { it.isNotBlank() },
        campaignId = if (z.has("CampaignId") && !z.isNull("CampaignId")) z.optInt("CampaignId") else null
      ))
    }

    return LayoutConfig(
      layoutId = layoutId,
      layoutName = layoutObj.optString("Name", "Layout"),
      zones = zones.sortedBy { it.zIndex }
    )
  }

  private fun showMultiZoneLayout(layout: LayoutConfig) {
    val key = "layout:${layout.layoutId}"
    if (currentContentKey == key) return

    currentContentKey = key
    currentLayoutId = layout.layoutId
    stopCampaignPlayback()
    stopVideo()

    // Clear existing zone views
    clearZoneViews()

    codeContainer.visibility = View.GONE
    playerView.visibility = View.GONE
    webView.visibility = View.GONE
    zoneContainer.visibility = View.VISIBLE
    zoneContainer.removeAllViews()

    val parentWidth = zoneContainer.width.takeIf { it > 0 } ?: window.decorView.width
    val parentHeight = zoneContainer.height.takeIf { it > 0 } ?: window.decorView.height

    for (zone in layout.zones) {
      val zoneView = createZoneView(zone, parentWidth, parentHeight)
      zoneContainer.addView(zoneView)
      zoneViews[zone.zoneName] = zoneView
    }
  }

  private fun createZoneView(zone: ZoneConfig, parentWidth: Int, parentHeight: Int): View {
    val x = (zone.xPercent / 100f * parentWidth).toInt()
    val y = (zone.yPercent / 100f * parentHeight).toInt()
    val w = (zone.widthPercent / 100f * parentWidth).toInt()
    val h = (zone.heightPercent / 100f * parentHeight).toInt()

    val webView = WebView(this).apply {
      layoutParams = FrameLayout.LayoutParams(w, h).also { lp ->
        lp.leftMargin = x
        lp.topMargin = y
      }
      settings.javaScriptEnabled = true
      settings.domStorageEnabled = true
      settings.mediaPlaybackRequiresUserGesture = false
      settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
      setBackgroundColor(Color.BLACK)
      webViewClient = WebViewClient()
      webChromeClient = WebChromeClient()

      // Enable touch events for interactive content
      setOnTouchListener { v, event -> handleZoneTouch(zone.zoneName, event); false }
    }

    // Load content based on zone configuration
    when {
      zone.menuPublicToken != null -> {
        val url = "${SettingsStore.PUBLIC_BASE_URL}/display/menu-ssr/${zone.menuPublicToken}"
        webView.loadUrl(url)
      }
      zone.contentUrl != null -> {
        val normalizedUrl = normalizeMediaUrl(zone.contentUrl)
        if (zone.contentType?.startsWith("video/") == true) {
          // For video zones, use HTML5 video
          webView.loadDataWithBaseURL("${SettingsStore.PUBLIC_BASE_URL}/",
            createVideoHtml(normalizedUrl), "text/html", "utf-8", null)
        } else {
          // For image zones
          webView.loadDataWithBaseURL("${SettingsStore.PUBLIC_BASE_URL}/",
            createImageHtml(normalizedUrl), "text/html", "utf-8", null)
        }
      }
      zone.campaignId != null -> {
        // Load campaign content in this zone
        loadCampaignInZone(webView, zone.campaignId)
      }
      else -> {
        webView.setBackgroundColor(Color.BLACK)
      }
    }

    return webView
  }

  private fun clearZoneViews() {
    for ((_, view) in zoneViews) {
      if (view is WebView) {
        view.stopLoading()
        view.loadUrl("about:blank")
      }
    }
    zoneViews.clear()
    currentLayoutId = null
  }

  private fun loadCampaignInZone(zoneWebView: WebView, campaignId: Int) {
    Thread {
      try {
        val hardwareId = SettingsStore.getOrCreateHardwareId(this)
        val provisioningToken = SettingsStore.getPairingCode(this).trim()
        val manifest = getCampaignManifest(hardwareId, provisioningToken, campaignId)
        val items = manifest.items.sortedBy { it.displayOrder }

        if (items.isEmpty()) {
          runOnUiThread { zoneWebView.setBackgroundColor(Color.BLACK) }
          return@Thread
        }

        // Simple zone campaign playback - cycle through items
        var idx = 0
        val zoneRunnable = object : Runnable {
          override fun run() {
            if (stopped) return
            val item = items[idx % items.size]
            idx++

            runOnUiThread {
              when {
                item.menuPublicToken != null -> {
                  val url = "${SettingsStore.PUBLIC_BASE_URL}/display/menu-ssr/${item.menuPublicToken}"
                  zoneWebView.loadUrl(url)
                }
                item.downloadUrl != null -> {
                  val normalizedUrl = normalizeMediaUrl(item.downloadUrl)
                  if (item.fileType?.startsWith("video/") == true) {
                    zoneWebView.loadDataWithBaseURL("${SettingsStore.PUBLIC_BASE_URL}/",
                      createVideoHtml(normalizedUrl), "text/html", "utf-8", null)
                  } else {
                    zoneWebView.loadDataWithBaseURL("${SettingsStore.PUBLIC_BASE_URL}/",
                      createImageHtml(normalizedUrl), "text/html", "utf-8", null)
                  }
                }
              }
            }

            val duration = (if (item.durationSec > 0) item.durationSec else 10).toLong() * 1000L
            handler.postDelayed(this, duration.coerceAtLeast(3_000L))
          }
        }
        handler.post(zoneRunnable)
      } catch (_: Exception) {
        runOnUiThread { zoneWebView.setBackgroundColor(Color.BLACK) }
      }
    }.start()
  }

  private fun createVideoHtml(url: String): String {
    val urlB64 = Base64.encodeToString(url.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
    return """
      <!doctype html>
      <html>
        <head><meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}video{width:100%;height:100%;object-fit:cover}</style>
        </head>
        <body>
          <video id="m" autoplay muted playsinline loop></video>
          <script>
            (function(){
              var v = document.getElementById('m');
              try { v.src = atob('$urlB64'); v.play(); } catch(e){}
            })();
          </script>
        </body>
      </html>
    """.trimIndent()
  }

  private fun createImageHtml(url: String): String {
    val safeUrl = url.replace("&", "&amp;").replace("\"", "&quot;")
      .replace("<", "&lt;").replace(">", "&gt;")
    return """
      <!doctype html>
      <html>
        <head><meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}img{width:100%;height:100%;object-fit:cover}</style>
        </head>
        <body><img src="$safeUrl" /></body>
      </html>
    """.trimIndent()
  }

  // ===== TOUCH INTERACTION SUPPORT =====

  private fun handleZoneTouch(zoneName: String, event: MotionEvent) {
    when (event.action) {
      MotionEvent.ACTION_DOWN -> {
        touchStartTime = System.currentTimeMillis()
        touchStartX = event.x
        touchStartY = event.y
      }
      MotionEvent.ACTION_UP -> {
        val duration = System.currentTimeMillis() - touchStartTime
        val dx = event.x - touchStartX
        val dy = event.y - touchStartY
        val distance = kotlin.math.sqrt((dx * dx + dy * dy).toDouble())

        val interactionType = when {
          distance > 100 && kotlin.math.abs(dx) > kotlin.math.abs(dy) -> if (dx > 0) "swipe_right" else "swipe_left"
          distance > 100 -> if (dy > 0) "swipe_down" else "swipe_up"
          duration > 500 -> "long_press"
          else -> "tap"
        }

        recordTouchInteraction(zoneName, interactionType, event.x, event.y)
      }
    }
  }

  private fun recordTouchInteraction(zoneName: String, interactionType: String, x: Float, y: Float) {
    Thread {
      try {
        val hardwareId = SettingsStore.getOrCreateHardwareId(this)
        val provisioningToken = SettingsStore.getPairingCode(this).trim()

        val url = URL("${SettingsStore.API_BASE_URL}/device/interaction")
        val body = JSONObject()
          .put("HardwareId", hardwareId)
          .put("ProvisioningToken", provisioningToken)
          .put("ZoneName", zoneName)
          .put("InteractionType", interactionType)
          .put("X", x.toInt())
          .put("Y", y.toInt())
          .put("Timestamp", System.currentTimeMillis())

        postJson(url, body)
      } catch (_: Exception) {
        // Silently ignore interaction recording failures
      }
    }.start()
  }

  // ===== TRANSITION EFFECTS =====

  private fun applyTransition(view: View, transitionType: String, onComplete: (() -> Unit)? = null) {
    val animation: Animation = when (transitionType.lowercase()) {
      "fade" -> AlphaAnimation(0f, 1f).apply {
        duration = transitionDurationMs
        interpolator = AccelerateDecelerateInterpolator()
      }
      "slide_left" -> TranslateAnimation(
        Animation.RELATIVE_TO_PARENT, 1f, Animation.RELATIVE_TO_PARENT, 0f,
        Animation.RELATIVE_TO_PARENT, 0f, Animation.RELATIVE_TO_PARENT, 0f
      ).apply {
        duration = transitionDurationMs
        interpolator = AccelerateDecelerateInterpolator()
      }
      "slide_right" -> TranslateAnimation(
        Animation.RELATIVE_TO_PARENT, -1f, Animation.RELATIVE_TO_PARENT, 0f,
        Animation.RELATIVE_TO_PARENT, 0f, Animation.RELATIVE_TO_PARENT, 0f
      ).apply {
        duration = transitionDurationMs
        interpolator = AccelerateDecelerateInterpolator()
      }
      "slide_up" -> TranslateAnimation(
        Animation.RELATIVE_TO_PARENT, 0f, Animation.RELATIVE_TO_PARENT, 0f,
        Animation.RELATIVE_TO_PARENT, 1f, Animation.RELATIVE_TO_PARENT, 0f
      ).apply {
        duration = transitionDurationMs
        interpolator = AccelerateDecelerateInterpolator()
      }
      "slide_down" -> TranslateAnimation(
        Animation.RELATIVE_TO_PARENT, 0f, Animation.RELATIVE_TO_PARENT, 0f,
        Animation.RELATIVE_TO_PARENT, -1f, Animation.RELATIVE_TO_PARENT, 0f
      ).apply {
        duration = transitionDurationMs
        interpolator = AccelerateDecelerateInterpolator()
      }
      "zoom_in" -> AnimationSet(true).apply {
        addAnimation(ScaleAnimation(0.5f, 1f, 0.5f, 1f,
          Animation.RELATIVE_TO_SELF, 0.5f, Animation.RELATIVE_TO_SELF, 0.5f))
        addAnimation(AlphaAnimation(0f, 1f))
        duration = transitionDurationMs
        interpolator = AccelerateDecelerateInterpolator()
      }
      "zoom_out" -> AnimationSet(true).apply {
        addAnimation(ScaleAnimation(1.5f, 1f, 1.5f, 1f,
          Animation.RELATIVE_TO_SELF, 0.5f, Animation.RELATIVE_TO_SELF, 0.5f))
        addAnimation(AlphaAnimation(0f, 1f))
        duration = transitionDurationMs
        interpolator = AccelerateDecelerateInterpolator()
      }
      else -> AlphaAnimation(1f, 1f).apply { duration = 0 } // No transition
    }

    animation.setAnimationListener(object : Animation.AnimationListener {
      override fun onAnimationStart(animation: Animation?) {}
      override fun onAnimationEnd(animation: Animation?) { onComplete?.invoke() }
      override fun onAnimationRepeat(animation: Animation?) {}
    })

    view.startAnimation(animation)
  }

  // ===== REMOTE COMMAND SUPPORT =====

  private data class RemoteCommand(
    val id: Int,
    val commandType: String,
    val payload: JSONObject?
  )

  private fun startCommandPolling(provisioningToken: String) {
    handler.post(object : Runnable {
      override fun run() {
        if (stopped) return
        Thread {
          try {
            val commands = fetchPendingCommands(provisioningToken)
            for (cmd in commands) {
              executeCommand(cmd)
              acknowledgeCommand(provisioningToken, cmd.id)
            }
          } catch (_: Exception) {
            // Silently ignore command polling failures
          }
          handler.postDelayed(this, commandPollIntervalMs)
        }.start()
      }
    })
  }

  private fun fetchPendingCommands(provisioningToken: String): List<RemoteCommand> {
    val hardwareId = SettingsStore.getOrCreateHardwareId(this)
    val url = URL("${SettingsStore.API_BASE_URL}/device/commands?hardwareId=$hardwareId&provisioningToken=$provisioningToken")
    val conn = (url.openConnection() as HttpURLConnection)
    conn.requestMethod = "GET"
    conn.connectTimeout = 8_000
    conn.readTimeout = 8_000

    val httpCode = conn.responseCode
    if (httpCode !in 200..299) return emptyList()

    val text = BufferedReader(InputStreamReader(conn.inputStream)).use { it.readText() }
    val arr = JSONArray(text)
    val commands = mutableListOf<RemoteCommand>()

    for (i in 0 until arr.length()) {
      val obj = arr.optJSONObject(i) ?: continue
      val id = obj.optInt("Id", 0)
      if (id <= lastCommandId) continue

      commands.add(RemoteCommand(
        id = id,
        commandType = obj.optString("CommandType", ""),
        payload = obj.optJSONObject("Payload")
      ))
    }

    return commands
  }

  private fun executeCommand(cmd: RemoteCommand) {
    when (cmd.commandType.lowercase()) {
      "reboot" -> {
        // Attempt soft restart of the app
        runOnUiThread {
          val intent = packageManager.getLaunchIntentForPackage(packageName)
          intent?.addFlags(android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
          startActivity(intent)
          finish()
        }
      }
      "screenshot" -> {
        runOnUiThread {
          captureAndUploadScreenshot(cmd.id)
        }
      }
      "volume" -> {
        val level = cmd.payload?.optInt("level", 50) ?: 50
        setSystemVolume(level)
      }
      "refresh" -> {
        runOnUiThread {
          webView.reload()
          for ((_, view) in zoneViews) {
            if (view is WebView) view.reload()
          }
        }
      }
      "set_brightness" -> {
        val brightness = cmd.payload?.optInt("brightness", 100) ?: 100
        setScreenBrightness(brightness)
      }
      "clear_cache" -> {
        runOnUiThread {
          webView.clearCache(true)
          for ((_, view) in zoneViews) {
            if (view is WebView) view.clearCache(true)
          }
        }
      }
    }

    lastCommandId = maxOf(lastCommandId, cmd.id)
  }

  private fun acknowledgeCommand(provisioningToken: String, commandId: Int) {
    try {
      val hardwareId = SettingsStore.getOrCreateHardwareId(this)
      val url = URL("${SettingsStore.API_BASE_URL}/device/commands/$commandId/ack")
      val body = JSONObject()
        .put("HardwareId", hardwareId)
        .put("ProvisioningToken", provisioningToken)
        .put("Status", "completed")
      postJson(url, body)
    } catch (_: Exception) {
      // Ignore ack failures
    }
  }

  private fun captureAndUploadScreenshot(commandId: Int) {
    try {
      // Capture the current screen
      val rootView = window.decorView.rootView
      val bitmap = Bitmap.createBitmap(rootView.width, rootView.height, Bitmap.Config.ARGB_8888)
      val canvas = Canvas(bitmap)
      rootView.draw(canvas)

      // Compress to JPEG
      val outputStream = ByteArrayOutputStream()
      bitmap.compress(Bitmap.CompressFormat.JPEG, 80, outputStream)
      val imageBytes = outputStream.toByteArray()
      val base64Image = Base64.encodeToString(imageBytes, Base64.NO_WRAP)

      // Upload screenshot
      Thread {
        try {
          val hardwareId = SettingsStore.getOrCreateHardwareId(this)
          val provisioningToken = SettingsStore.getPairingCode(this).trim()
          val url = URL("${SettingsStore.API_BASE_URL}/device/screenshot")
          val body = JSONObject()
            .put("HardwareId", hardwareId)
            .put("ProvisioningToken", provisioningToken)
            .put("CommandId", commandId)
            .put("ImageData", base64Image)
            .put("ContentType", "image/jpeg")
          postJson(url, body)
        } catch (_: Exception) {
          // Ignore upload failures
        }
      }.start()

      bitmap.recycle()
    } catch (_: Exception) {
      // Ignore screenshot failures
    }
  }

  private fun setSystemVolume(level: Int) {
    try {
      val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
      val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
      val targetVolume = (level / 100f * maxVolume).toInt().coerceIn(0, maxVolume)
      audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, 0)
    } catch (_: Exception) {
      // Ignore volume control failures
    }
  }

  private fun setScreenBrightness(brightness: Int) {
    try {
      val layoutParams = window.attributes
      layoutParams.screenBrightness = (brightness / 100f).coerceIn(0.01f, 1f)
      window.attributes = layoutParams
    } catch (_: Exception) {
      // Ignore brightness control failures
    }
  }
}
