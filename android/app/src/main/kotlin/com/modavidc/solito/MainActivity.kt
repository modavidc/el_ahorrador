package com.modavidc.solito

import android.os.Bundle
import android.view.WindowManager
import com.modavidc.solito.capture.AppChannel
import com.modavidc.solito.capture.CapturePermissions
import com.modavidc.solito.reminders.Reminders
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (resources.getBoolean(R.bool.block_screenshots)) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AppChannel.attach(this, flutterEngine.dartExecutor.binaryMessenger)
        Reminders.attach(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onResume() {
        super.onResume()
        // Permissions may have changed in system settings.
        AppChannel.pushState(this)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CapturePermissions.REQUEST_CODE) AppChannel.pushState(this)
    }

    override fun onDestroy() {
        AppChannel.detach()
        super.onDestroy()
    }
}
