package net.alkatrazstudio.polarmon

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.OutputStream
import java.io.PrintWriter
import java.io.StringWriter

class MainActivity: FlutterActivity() {

    companion object {
        private const val CHANNEL = "polarmon.alkatrazstudio.net/storage"
        private const val SAVE_FILE_REQUEST_CODE = 1
        private const val LOAD_FILE_REQUEST_CODE = 2
    }

    private var pendingBytes: ByteArray? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result -> try {
                val args = call.arguments<HashMap<String, Any>>()
                if(args == null) {
                    result.error("args", "arguments are null", null)
                } else {
                    when (call.method) {
                        "saveFile" -> saveFile(
                            args["initialFilename"] as String,
                            args["mime"] as String,
                            args["bytes"] as ByteArray,
                            result
                        )
                        "loadFile" -> loadFile(
                            args["mime"] as String,
                            result
                        )
                        else -> result.notImplemented()
                    }
                }
            } catch(e: Throwable) {
                Log.wtf("MethodChannel", "${call.method} error [${e.javaClass.name}]: ${e.message}", e)
                result.error(e.javaClass.name, e.message, stackTraceFromException(e))
            }
        }
    }

    private fun saveFile(initialFilename: String, mime: String, bytes: ByteArray, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("pending", "There's already a pending request", null)
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        intent.putExtra(Intent.EXTRA_TITLE, initialFilename)
        intent.setType(mime)
        startActivityForResult(intent, SAVE_FILE_REQUEST_CODE)
        pendingBytes = bytes
        pendingResult = result
    }

    private fun loadFile(mime: String, result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_GET_CONTENT)
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        intent.setType(mime)
        startActivityForResult(intent, LOAD_FILE_REQUEST_CODE)
        pendingResult = result
    }

    private fun stackTraceFromException(e: Throwable): String {
        val sw = StringWriter()
        e.printStackTrace(PrintWriter(sw))
        val result = sw.toString()
        return result
    }

    private fun uriFromActivityResult(resultCode: Int, data: Intent?, result: MethodChannel.Result): Uri? {
        if(resultCode == Activity.RESULT_CANCELED) {
            result.success(null)
            return null
        }
        if(data == null) {
            result.error("data", "intent data is null", null)
            return null
        }
        val uri = data.data
        if(uri == null) {
            result.error("uri", "returned URI is null", null)
            return null
        }
        return uri
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val result = pendingResult
        if(result != null) {
            if(requestCode == SAVE_FILE_REQUEST_CODE) {
                pendingResult = null
                val bytes = pendingBytes
                pendingBytes = null
                val uri = uriFromActivityResult(resultCode, data, result) ?: return
                var stream: OutputStream? = null
                try {
                    stream = contentResolver.openOutputStream(uri, "wt")
                    if (stream == null) {
                        result.error("open", "cannot open the output stream", null)
                        return
                    }
                    stream.write(bytes)
                    stream.flush()
                    result.success(uri.toString())
                    return
                } catch(e: Exception) {
                    result.error("stream", e.message, null)
                } finally {
                    stream?.close()
                }
            } else if(requestCode == LOAD_FILE_REQUEST_CODE) {
                pendingResult = null
                val uri = uriFromActivityResult(resultCode, data, result) ?: return
                var stream: InputStream? = null
                try {
                    stream = contentResolver.openInputStream(uri)
                    if (stream == null) {
                        result.error("open", "cannot open the output stream", null)
                        return
                    }
                    val bytes = stream.readBytes()
                    result.success(bytes)
                    return
                } catch(e: Exception) {
                    result.error("stream", e.message, null)
                } finally {
                    stream?.close()
                }
            }
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
