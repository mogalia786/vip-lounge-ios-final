package com.example.vip_lounge

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import android.Manifest
import android.os.Build
import androidx.core.app.ActivityCompat
import android.app.Activity
import android.os.Looper
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationResult

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.yourcompany.vip/location"
    private lateinit var fusedLocationClient: FusedLocationProviderClient

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getCurrentLocation") {
                getCurrentLocation(result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getCurrentLocation(result: MethodChannel.Result) {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Location permission not granted", null)
            return
        }
        fusedLocationClient.lastLocation.addOnSuccessListener { location ->
            if (location != null) {
                val locMap = hashMapOf<String, Double>(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude
                )
                result.success(locMap)
            } else {
                result.error("LOCATION_ERROR", "Could not fetch location", null)
            }
        }.addOnFailureListener {
            result.error("LOCATION_ERROR", "Could not fetch location", null)
        }
    }
}
