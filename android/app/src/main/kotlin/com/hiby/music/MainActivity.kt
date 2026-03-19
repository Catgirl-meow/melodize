package com.hiby.music

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceFragmentActivity

// AudioServiceFragmentActivity extends FlutterFragmentActivity and overrides
// provideFlutterEngine / getCachedEngineId to register the engine in
// FlutterEngineCache under audio_service's key.  Without this, the plugin's
// wrongEngineDetected check fails because it creates a second engine whose
// BinaryMessenger doesn't match the one the plugin binding received.
class MainActivity : AudioServiceFragmentActivity() {

    override fun onResume() {
        super.onResume()
        // Android 13+ requires POST_NOTIFICATIONS at runtime for the media
        // notification.  Without it audio_service cannot start its foreground
        // service, which also prevents headphone/Bluetooth media buttons from
        // routing to this app's MediaSession.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    1
                )
            }
        }
    }
}
