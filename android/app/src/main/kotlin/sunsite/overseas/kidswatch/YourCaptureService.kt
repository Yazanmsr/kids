package sunsite.overseas.kidswatch

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.*


class YourCaptureService : Service() {

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var handler: Handler? = null
    private var captureRunnable: Runnable? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP_PROJECTION") {
            stopProjection()
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        }



        startForegroundService()

        val resultCode = intent?.getIntExtra("resultCode", Activity.RESULT_CANCELED)
            ?: return START_NOT_STICKY
        val data = intent.getParcelableExtra<Intent>("data")
            ?: return START_NOT_STICKY

        val projectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = projectionManager.getMediaProjection(resultCode, data)


        startCapture()

        return START_STICKY
    }

    private fun stopProjection() {
        mediaProjection?.stop()
        mediaProjection = null


    }



    private fun startForegroundService() {
        val channelId = "KidsWatchChannel"
        val channelName = "KidsWatch Capture Service"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("KidsWatch running")
            .setContentText("Capturing screen periodically...")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .build()

        startForeground(1001, notification)
    }

    private fun startCapture() {
        val metrics = resources.displayMetrics
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi

        imageReader = ImageReader.newInstance(width, height, 0x1, 2)

        handler = Handler(mainLooper)

        // ✅ Required for Android 13+ (API 33)
        mediaProjection?.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                super.onStop()
                Log.i("KidsWatch", "📴 MediaProjection stopped by system.")
                stopSelf()
            }
        }, handler)

        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "KidsWatchVirtualDisplay",
            width,
            height,
            density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            null
        )

        captureRunnable = object : Runnable {
            override fun run() {
                captureScreenshot()
                handler?.postDelayed(this, 300_000) // every 5 minutes
            }
        }
        handler?.post(captureRunnable!!)
    }




    private fun captureScreenshot() {
        val image = imageReader?.acquireLatestImage() ?: return

        val planes = image.planes
        if (planes.isEmpty()) {
            image.close()
            Log.e("KidsWatch", "❌ No planes in image.")
            return
        }

        val buffer = planes[0].buffer
        val pixelStride = planes[0].pixelStride
        val rowStride = planes[0].rowStride
        val rowPadding = rowStride - pixelStride * image.width

        val bitmap = Bitmap.createBitmap(
            image.width + rowPadding / pixelStride,
            image.height,
            Bitmap.Config.ARGB_8888
        )
        bitmap.copyPixelsFromBuffer(buffer)
        image.close()

        saveBitmap(bitmap)
    }

    private fun saveBitmap(bitmap: Bitmap) {
        try {
            val appDir = File(filesDir, "KidsWatchScreenshots")
            if (!appDir.exists()) {
                appDir.mkdirs()
            }

            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val fileName = "screenshot_$timestamp.png"
            val file = File(appDir, fileName)

            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }

            Log.i("KidsWatch", "✅ Screenshot saved at: ${file.absolutePath}")
        } catch (e: Exception) {
            Log.e("KidsWatch", "❌ Failed to save screenshot: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler?.removeCallbacks(captureRunnable!!)
        virtualDisplay?.release()
        mediaProjection?.stop()
        imageReader?.close()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
