package dev.thereis.duplicate_file_remover

import android.media.MediaScannerConnection
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 파일 삭제/이동/복원 후 갤러리(MediaStore) 갱신.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "duplicate_remover/media")
            .setMethodCallHandler { call, result ->
                if (call.method == "scanFiles") {
                    val paths = call.arguments<List<String>>() ?: emptyList()
                    MediaScannerConnection.scanFile(this, paths.toTypedArray(), null, null)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
