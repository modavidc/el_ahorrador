package com.elahorrador.app.capture

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Headless Flutter engine that runs `backgroundCaptureMain` in Dart and
 * stays warm while the capture service lives, so each payment is read and
 * registered in 1–2 seconds even with the app closed.
 */
object BackgroundEngine {
    private const val CHANNEL = "el_ahorrador/capture_background"

    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false
    private val pending = mutableListOf<() -> Unit>()

    fun processImage(context: Context, path: String, done: (Map<*, *>?) -> Unit) =
        call(context, "processImage", path, done)

    fun processText(
        context: Context,
        text: String,
        source: String,
        done: (Map<*, *>?) -> Unit,
    ) = call(context, "processText", mapOf("text" to text, "source" to source), done)

    fun undo(context: Context, movementId: String, done: () -> Unit) =
        call(context, "undo", movementId) { done() }

    /** Starts the engine ahead of the first payment. */
    fun warmUp(context: Context) = main.post { ensure(context.applicationContext) }

    fun destroy() = main.post {
        engine?.destroy()
        engine = null
        channel = null
        ready = false
        pending.clear()
    }

    private fun call(
        context: Context,
        method: String,
        arguments: Any?,
        done: (Map<*, *>?) -> Unit,
    ) = main.post {
        ensure(context.applicationContext)
        val run = {
            channel?.invokeMethod(
                method,
                arguments,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        done(result as? Map<*, *>)
                        AppChannel.notifyCaptured()
                    }

                    override fun error(code: String, message: String?, details: Any?) =
                        done(null)

                    override fun notImplemented() = done(null)
                },
            ) ?: done(null)
        }
        if (ready) run() else pending += run
    }

    private fun ensure(context: Context) {
        if (engine != null) return
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(context)
        loader.ensureInitializationComplete(context, null)
        val created = FlutterEngine(context)
        channel = MethodChannel(created.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "ready") {
                    ready = true
                    pending.forEach { it() }
                    pending.clear()
                }
                result.success(null)
            }
        }
        created.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "backgroundCaptureMain"),
        )
        engine = created
    }
}
