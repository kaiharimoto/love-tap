package io.lovetap.desk

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

/**
 * The web app, as the phone that serves it holds it.
 *
 * The iPhone has nothing to install until the Android phone hands it a page, and the Android phone
 * had nothing to hand over: `pwaRoot` was a parameter only the capture's far phone ever passed, so
 * every static GET on a real host answered 404 and step four of docs/PHONES.md — open the host's
 * address in Safari, add to home screen — could not be followed.
 *
 * What is in here is the web build with `assets/assets/**` taken out of it: the page, the engine,
 * the service worker, the icons. The eighty megabytes that were removed are the material library,
 * and the phone already has those in its own `flutter_assets`; the Dart side serves that half out
 * of `rootBundle` and this half out of here, and the browser cannot tell the difference.
 *
 * It lives in Android's own assets rather than Flutter's for one reason: anything under
 * `app/assets/` is bundled into `flutter build web` as well, so a copy of the web build stored
 * there would be packed inside the next web build, and inside the one after that.
 */
object Pwa {
    fun attach(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "lovetap/pwa").setMethodCallHandler { call, result ->
            when (call.method) {
                // Bytes, or null when this build carries no copy of that file. Null is an answer:
                // the server turns it into a 404 rather than a failed request.
                "read" -> {
                    val path = call.argument<String>("path")
                    if (path == null || !safe(path)) {
                        result.success(null)
                    } else {
                        result.success(read(context, "pwa/$path"))
                    }
                }
                // Whether there is a web app in here at all, which is what the setup list wants to
                // know before it tells anyone to open an address in Safari.
                "present" -> result.success(read(context, "pwa/index.html") != null)
                else -> result.notImplemented()
            }
        }
    }

    /** No leading slash, no `..`, no backslashes: the asset manager would happily walk out. */
    private fun safe(path: String): Boolean =
        !path.startsWith("/") && !path.contains("\\") &&
            path.split("/").none { it == ".." || it == "." || it.isEmpty() }

    private fun read(context: Context, name: String): ByteArray? = try {
        context.assets.open(name).use { it.readBytes() }
    } catch (e: IOException) {
        null
    }
}
