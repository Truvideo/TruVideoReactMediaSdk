package com.truvideoreactmediasdk

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.UiThreadUtil.runOnUiThread
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.google.gson.Gson
import com.truvideo.sdk.media.TruvideoSdkMedia
import com.truvideo.sdk.media.exception.TruvideoSdkMediaException
import com.truvideo.sdk.media.interfaces.TruvideoSdkMediaFileUploadCallback
import com.truvideo.sdk.media.model.TruvideoSdkMediaFileUploadRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject


class TruVideoReactMediaSdkModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String {
    return NAME
  }

  // Example method
  // See https://reactnative.dev/docs/native-modules-android

  @ReactMethod
  fun uploadMedia(filePath: String,tag : String,metaData : String,promise: Promise) {
    CoroutineScope(Dispatchers.Main).launch {
      uploadFile(reactApplicationContext,filePath,tag,metaData,promise)
    }
  }

  suspend fun uploadFile(context: Context, filePath: String,tag : String,metaData : String,promise: Promise){
    // Create a file upload request builder
    val builder = TruvideoSdkMedia.FileUploadRequestBuilder(filePath)
    val jsonTag = JSONObject(tag)
    builder.addTag("key",jsonTag.getString("key"))
    builder.addTag("color", jsonTag.getString("color"))
    builder.addTag("order-number", jsonTag.getString("orderNumber"))
    // Metadata
    val jsonMetadata = JSONObject(metaData)
    Log.d("TAG", "uploadFile: $jsonTag , $jsonMetadata")
    builder.setMetadata(
      mapOf<String, Any?>(
        "key" to jsonMetadata.getString("key"),
        "key1" to jsonMetadata.getString("key1"),
        "nested" to jsonMetadata.getJSONArray("key2")
      )
    )

    // Build the request
    val request = builder.build()

    val gson = Gson()
    // Upload the file
    request.upload(object : TruvideoSdkMediaFileUploadCallback {
      override fun onComplete(id: String, response: TruvideoSdkMediaFileUploadRequest) {
        // Handle completion
        val mainResponse = mapOf<String, Any?>(
          "id" to id,
          "response" to response
        )
        promise.resolve(gson.toJson(mainResponse))

        sendEvent(reactApplicationContext,"onComplete",gson.toJson(mainResponse))
      }

      override fun onProgressChanged(id: String, progress: Float) {
        // Handle progress
        val mainResponse = mapOf<String, Any?>(
          "id" to id,
          "progress" to progress
        )
        sendEvent(reactApplicationContext,"onProgress",gson.toJson(mainResponse))
      }

      override fun onError(id: String, ex: TruvideoSdkMediaException) {
        // Handle error
        val mainResponse = mapOf<String, Any?>(
          "id" to id,
          "error" to ex
        )
        promise.resolve(gson.toJson(mainResponse))
        sendEvent(reactApplicationContext,"onError",gson.toJson(mainResponse))
      }
    })
  }
  fun sendEvent(reactContext: ReactApplicationContext, eventName: String, progress: String) {
    reactContext
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(eventName, progress)
  }
  companion object {
    const val NAME = "TruVideoReactMediaSdk"
  }
}
