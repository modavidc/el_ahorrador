package com.elahorrador.app

import io.flutter.embedding.android.FlutterFragmentActivity
import android.os.Bundle
import android.view.WindowManager

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (resources.getBoolean(R.bool.block_screenshots)) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
