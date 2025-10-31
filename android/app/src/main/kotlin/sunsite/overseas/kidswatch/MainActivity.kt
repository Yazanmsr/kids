package sunsite.overseas.kidswatch

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SCREEN_CAPTURE_CHANNEL = "screen_capture_channel"
    private val BATTERY_OPTIMIZATIONS_CHANNEL = "battery_optimizations"
    private val REQUEST_MEDIA_PROJECTION = 9999

    private var projectionIntentData: Intent? = null
    private var projectionResultCode: Int = Activity.RESULT_CANCELED

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Screen capture channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CAPTURE_CHANNEL).setMethodCallHandler {
                call, result ->
            when (call.method) {
                "startProjection" -> {
                    Log.i("KidsWatch", "✅ startProjection called from Flutter.")
                    startMediaProjectionRequest()
                    result.success("Projection dialog opened.")
                }
                "stopProjection" -> {
                    Log.i("KidsWatch", "✅ stopProjection called from Flutter.")
                    stopMediaProjection()
                    result.success("Projection stopped.")
                }
                else -> result.notImplemented()
            }
        }

        // Battery optimization channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_OPTIMIZATIONS_CHANNEL).setMethodCallHandler {
                call, result ->
            if (call.method == "requestIgnoreBatteryOptimizations") {
                val packageName = applicationContext.packageName
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success(true)
                } else {
                    result.error("UNSUPPORTED", "Battery optimizations not supported", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startMediaProjectionRequest() {
        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val intent = projectionManager.createScreenCaptureIntent()
        startActivityForResult(intent, REQUEST_MEDIA_PROJECTION)
    }

    private fun stopMediaProjection() {
        Log.i("KidsWatch", "✅ stopMediaProjection called.")
        val stopIntent = Intent(this, YourCaptureService::class.java)
        stopIntent.action = "STOP_PROJECTION"
        startService(stopIntent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_MEDIA_PROJECTION) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                Log.i("KidsWatch", "✅ MediaProjection permission granted!")

                projectionResultCode = resultCode
                projectionIntentData = data

                val serviceIntent = Intent(this, YourCaptureService::class.java)
                serviceIntent.putExtra("resultCode", resultCode)
                serviceIntent.putExtra("data", data)
                startForegroundService(serviceIntent)
            } else {
                Log.e("KidsWatch", "❌ User denied MediaProjection permission.")
            }
        }
    }
}
