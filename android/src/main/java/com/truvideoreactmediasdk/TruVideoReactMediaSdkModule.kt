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
import com.truvideo.sdk.media.interfaces.TruvideoSdkMediaCallback
import com.truvideo.sdk.media.interfaces.TruvideoSdkMediaFileUploadCallback
import com.truvideo.sdk.media.model.TruvideoSdkMediaFileType
import com.truvideo.sdk.media.model.TruvideoSdkMediaFileUploadRequest
import com.truvideo.sdk.media.model.TruvideoSdkMediaFileUploadStatus
import com.truvideo.sdk.media.model.TruvideoSdkMediaMetadata
import com.truvideo.sdk.media.model.TruvideoSdkMediaTags
import com.truvideo.sdk.media.util.toIsoString
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import truvideo.sdk.common.exceptions.TruvideoSdkException
import java.io.File


class TruVideoReactMediaSdkModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String {
    return NAME
  }
  val scope = CoroutineScope(Dispatchers.IO)

    // Required by React Native for event emitter
    @ReactMethod
    fun addListener(eventName: String) {
        // Keep empty — React Native calls this when JS subscribes to events
    }

    @ReactMethod
    fun removeListeners(count: Int) {
        // Keep empty — React Native calls this when JS unsubscribes
    }

  // Upload Media
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
    val metaData = TruvideoSdkMediaMetadata.builder()
      .set("key",jsonMetadata.getString("key"))
      .set("key1",jsonMetadata.getString("key1"))
      .set("nested",jsonMetadata.getString("key2"))
      .build()
    builder.setMetadata(metaData)

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
          "progress" to (progress*100)
        )
        sendEvent(reactApplicationContext,"onProgress",gson.toJson(mainResponse))
      }

      override fun onError(id: String, ex: TruvideoSdkException) {
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


  @ReactMethod
  fun mediaBuilder(filePath: String?, tag: String?, metaData: String?, promise: Promise?) {
    try {
      val file = File(filePath!!)
      if(!file.exists()){
        promise!!.reject("File Exceptions","File not found")
      }else{
        scope.launch {
          builder(filePath,tag!!,metaData!!,promise!!)
        }
      }
//      CoroutineScope(Dispatchers.Main).launch {
//        builder(filePath,tag!!,metaData!!,promise!!)
//      }
    }catch (e : Exception){
      promise!!.reject("Exception",e.message)
    }
  }

  fun returnRequestsJson(requests: List<TruvideoSdkMediaFileUploadRequest>): String {
    val jsonArray = JSONArray()

    for (request in requests) {
      val jsonObject = JSONObject().apply {
        put("id", request.id)
        put("filePath", request.filePath)
        put("fileType", request.type)
        put("createdAt", request.createdAt.toIsoString())
        put("updateAt", request.updatedAt.toIsoString())
        put("tags", request.tags)
        put("metadata", request.metadata)
        put("durationMilliseconds", request.durationMilliseconds)
        put("remoteId", request.remoteId)
        put("remoteURL", request.remoteUrl)
        put("transcriptionURL", request.transcriptionUrl)
        put("transcriptionLength", request.transcriptionLength)
        put("status", request.status)
        put("progress", request.uploadProgress)
      }
      jsonArray.put(jsonObject)
    }

    return jsonArray.toString()
  }

  fun returnRequest(request : TruvideoSdkMediaFileUploadRequest) : String{
    return JSONObject().apply {
      put("id", request.id)
      put("filePath", request.filePath)
      put("fileType", request.type)
      put("createdAt", request.createdAt.toIsoString() )
      put("updateAt",request.updatedAt.toIsoString())
      put("tags" , request.tags)
      put("metadata", request.metadata)
      put("durationMilliseconds", request.durationMilliseconds)
      put("remoteId", request.remoteId)
      put("remoteURL", request.remoteUrl)
      put("transcriptionURL", request.transcriptionUrl)
      put("transcriptionLength", request.transcriptionLength)
      put("status", request.status)
      put("progress", request.uploadProgress)
    }.toString()
  }

  fun builder(filePath: String, tag : String, metaData : String, promise: Promise){
    // Create a file upload request builder
    try{
      val builder = TruvideoSdkMedia.FileUploadRequestBuilder(filePath)
      val jsonTag = JSONObject(tag)
      val keys = jsonTag.keys()
      while (keys.hasNext()) {
        val key = keys.next()
        val value= jsonTag.getString(key) // Can be any type: String, Integer, Boolean, etc.
        builder.addTag(key, value)
      }
      // Metadata
      val jsonMetadata = JSONObject(metaData)
      val metadataKeys = jsonMetadata.keys()
      while (metadataKeys.hasNext()) {
        val key = metadataKeys.next()
        val value = jsonMetadata.getString(key) // Can be any type: String, Integer, Boolean, etc.
        builder.addMetadata(key, value)
      }

      // Build the request
      builder.build(object:
        TruvideoSdkMediaCallback<TruvideoSdkMediaFileUploadRequest> {
        override fun onComplete(data: TruvideoSdkMediaFileUploadRequest) {
          val mainResponse = returnRequest(data)
          // Upload the file
          promise.resolve(mainResponse)
        }
        override fun onError(exception: TruvideoSdkException) {
          promise.reject("TruvideoSdkException",exception.message)
        }
      })
    }catch (e: Exception){
      promise.reject("Exception",e.message)
    }
  }

  @ReactMethod
  fun getFileUploadRequestById(id: String?, promise: Promise?) {
    try{
      scope.launch {
        val request = TruvideoSdkMedia.getFileUploadRequestById(id!!)
        if(request == null){
          promise!!.resolve("{}")
        }else{
          val mainResponse = returnRequest(request)
          promise!!.resolve(mainResponse)
        }
      }
    }catch (e: Exception){
      promise!!.reject("Exception",e.message)
    }
  }

  @ReactMethod
  fun getAllFileUploadRequests(status: String?, promise: Promise?) {
    try{
      scope.launch {
        if(status == ""){
          val request = TruvideoSdkMedia.getAllFileUploadRequests()
          promise!!.resolve(returnRequestsJson(request))
        }else{
          val mainStatus : TruvideoSdkMediaFileUploadStatus? = when(status) {
            "UPLOADING" -> TruvideoSdkMediaFileUploadStatus.UPLOADING
            "IDLE" -> TruvideoSdkMediaFileUploadStatus.IDLE
            "ERROR" -> TruvideoSdkMediaFileUploadStatus.ERROR
            "PAUSED" -> TruvideoSdkMediaFileUploadStatus.PAUSED
            "COMPLETED" -> TruvideoSdkMediaFileUploadStatus.COMPLETED
            "CANCELED" -> TruvideoSdkMediaFileUploadStatus.CANCELED
            "SYNCHRONIZING" -> TruvideoSdkMediaFileUploadStatus.SYNCHRONIZING
            else -> null
          }
          val request = TruvideoSdkMedia.getAllFileUploadRequests(mainStatus)
          promise!!.resolve(returnRequestsJson(request))
        }
      }
    }catch (e: Exception){
      promise!!.reject("Exception",e.message)
    }
  }

  @ReactMethod
  fun cancelMedia(id: String?, promise: Promise?) {
    try{
      scope.launch {
        val request = TruvideoSdkMedia.getFileUploadRequestById(id!!)
        request!!.cancel()
        promise!!.resolve("Cancel Success")
      }
    }catch (e: Exception){
      promise!!.reject("Exception",e.message)
    }
  }

  @ReactMethod
  fun deleteMedia(id: String?, promise: Promise?) {
    try{
      scope.launch {
        val request = TruvideoSdkMedia.getFileUploadRequestById(id!!)
        request!!.delete()
        promise!!.resolve("Delete Success")
      }
    }catch (e: Exception){
      promise!!.reject("Exception",e.message)
    }
  }

  @ReactMethod
  fun pauseMedia(id: String?, promise: Promise?) {
    try{
      scope.launch {
        val request = TruvideoSdkMedia.getFileUploadRequestById(id!!)
        request!!.pause()
        promise!!.resolve("Pause Success")
      }
    }catch (e: Exception){
      promise!!.reject("Exception",e.message)
    }
  }

  @ReactMethod
  fun resumeMedia(id: String?, promise: Promise?) {
    try{
      scope.launch {
        val request = TruvideoSdkMedia.getFileUploadRequestById(id!!)
        request!!.resume()
        promise!!.resolve("Resume Success")
      }
    }catch (e: Exception){
      promise!!.reject("Exception",e.message)
    }
  }



  @ReactMethod
  fun search(
    tag: String?,
    type: String?,
    page: String?,
    pageSize: String?,
    promise: Promise?
  ) {
    try{
      scope.launch {
        val typeData : TruvideoSdkMediaFileType = when (type) {
          "Video" -> {
            TruvideoSdkMediaFileType.Video
          }
          "AUDIO" -> {
            TruvideoSdkMediaFileType.AUDIO
          }
          "PDF" -> {
            TruvideoSdkMediaFileType.PDF
          }
          "Image" -> {
            TruvideoSdkMediaFileType.Picture
          }
          else -> {
            TruvideoSdkMediaFileType.All
          }
        }
        val jsonTag = JSONObject(tag!!)
        val map = mutableMapOf<String, String>()
        val keys = jsonTag.keys()
        while (keys.hasNext()) {
          val key = keys.next()
          val value= jsonTag.getString(key)
          map[key] = value
        }
        val response = TruvideoSdkMedia.search(
          tags = TruvideoSdkMediaTags(map),
          type = typeData,
          pageNumber = page!!.toInt(),
          pageSize = pageSize!!.toInt()
        )
        val jsonArray = JSONArray()

        response.data.forEach { item ->
          val metadataObj = JSONObject()
          item.metadata.map.keys.forEach { key ->
            metadataObj.put(key, item.metadata.map[key])
          }
          val tagsObj = JSONObject()
          item.tags.map.keys.forEach { key ->
            tagsObj.put(key, item.tags.map[key])
          }

          val jsonObject = JSONObject().apply {
            put("id", item.id)
            put("createdDate", item.createdDate.toIsoString())
            put("remoteId", item.id)
            put("uploadedFileURL", item.url)
            put("metaData", metadataObj) // assuming toJson() returns JSON string
            put("tags", tagsObj) // assuming toJson() returns JSON array string
            put("transcriptionURL", item.transcriptionUrl)
            put("transcriptionLength", item.transcriptionLength)
            put("fileType", item.type.name)
            put("thumbnailUrl", item.thumbnailUrl)
            put("previewUrl", item.previewUrl)
          }
          jsonArray.put(jsonObject)
        }

// Resolve with JSON string
        promise!!.resolve(jsonArray.toString())
      }
    }catch (e: Exception){
      promise!!.reject("Exception",e.message)
    }
  }


  // broadcast event
  fun sendEvent(reactContext: ReactApplicationContext, eventName: String, progress: String) {
    reactContext
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(eventName, progress)
  }
  companion object {
    const val NAME = "TruVideoReactMediaSdk"
  }
}
