package co.displaydeck.player

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.graphics.Color
import android.view.WindowManager
import android.view.View
import android.widget.TextView
import android.util.Base64
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
  private lateinit var playerView: PlayerView
  private var player: ExoPlayer? = null
  private lateinit var debugOverlay: TextView
  private lateinit var versionOverlay: TextView
  private val overlayLines = ArrayDeque<String>()

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
    val infoBoardPublicToken: String?
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
    return HeartbeatStatus(displayName = displayName, assignmentType = type, menuPublicToken = menuToken, campaignId = campaignId, infoBoardPublicToken = infoBoardToken)
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
