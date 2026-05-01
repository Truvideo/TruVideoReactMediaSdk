package com.truvideoreactmediasdk
import android.os.Build
import android.util.Log
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.truvideo.sdk.media.TruvideoSdkMedia
import com.truvideo.sdk.media.interfaces.TruvideoSdkMediaCallback
import com.truvideo.sdk.media.interfaces.TruvideoSdkMediaFileUploadCallback
import com.truvideo.sdk.media.model.external.TruvideoSdkMediaFileType
import com.truvideo.sdk.media.model.external.TruvideoSdkMediaFileUploadRequest
import com.truvideo.sdk.media.model.external.TruvideoSdkMediaFileUploadRequestStatus
//import com.truvideo.sdk.media.util.toIsoString
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import org.json.JSONArray
import org.json.JSONObject
import com.truvideo.sdk.media.model.external.TruvideoSdkMediaTags
//import truvideo.sdk.common.exceptions.TruvideoSdkException
import java.io.File
import kotlinx.coroutines.withContext
import org.json.JSONException
import java.time.format.DateTimeFormatter
import com.truvideo.sdk.media.model.external.TruvideoSdkMediaModel
import com.truvideo.sdk.media.model.external.TruvideoSdkMediaResponse
import com.truvideo.sdk.media.model.external.TruvideoSdkMediaUploadRequest
import com.truvideo.sdk.media.model.external.TruvideoSdkMediaMetadata
import com.truvideo.sdk.model.exceptions.TruvideoSdkException

class TruVideoReactMediaSdkModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String {
        return NAME
    }
    val scope = CoroutineScope(Dispatchers.IO)

    @ReactMethod
    fun addListener(eventName: String) {
        // Keep empty — React Native calls this when JS subscribes to events
    }

    @ReactMethod
    fun removeListeners(count: Int) {
        // Keep empty — React Native calls this when JS unsubscribes
    }
  // ─── Date Helper ─────────────────────────────────────────────────────────

  private fun formatDate(date: java.util.Date?): String? {
    if (date == null) return null
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      DateTimeFormatter.ISO_INSTANT.format(date.toInstant())
    } else {
      date.toString()
    }
  }


    @ReactMethod
    fun uploadMedia(id: String, promise: Promise) {
      try {
        TruvideoSdkMedia.getFileUploadRequestById(
          id,
          object : TruvideoSdkMediaCallback<TruvideoSdkMediaFileUploadRequest?> {
            override fun onComplete(data: TruvideoSdkMediaFileUploadRequest?) {
              if (data == null) {
                promise.reject("File Exceptions", "Upload request not found")
                return
              }
              val file = File(data.filePath)
              if (!file.exists()) {
                promise.reject("File Exceptions", "File not found")
                return
              }
              data.upload(
                object : TruvideoSdkMediaCallback<Unit> {
                  override fun onComplete(data: Unit) { }
                  override fun onError(exception: TruvideoSdkException) {
                    promise.reject("TruvideoSdkException", exception.message)
                  }
                },
                object : TruvideoSdkMediaFileUploadCallback {
                  override fun onComplete(id: String, response: TruvideoSdkMediaFileUploadRequest) {
                    val metadataObj = JSONObject(response.metadata.toMap() as Map<*, *>)
                    val tagsObj = JSONObject(response.tags.toMap() as Map<*, *>)
                    val mainResponse = JSONObject().apply {
                      put("id", id)
                      put("createdDate", formatDate(response.createdAt))
                      put("remoteId", response.mediaId ?: "")
                      put("uploadedFileURL", response.mediaUrl ?: "")
                      put("metaData", metadataObj)
                      put("tags", tagsObj)
                      put("transcriptionURL", response.transcriptionUrl ?: "")
                      put("fileType", response.fileType.name)
                    }
                    promise.resolve(mainResponse.toString())
                    sendEvent(reactApplicationContext, "onComplete", mainResponse.toString())
                  }

                  override fun onProgressChanged(id: String, progress: Float) {
                    val mainResponse = JSONObject().apply {
                      put("id", id)
                      put("progress", progress * 100)
                    }
                    sendEvent(reactApplicationContext, "onProgress", mainResponse.toString())
                  }

                  override fun onError(id: String, ex: TruvideoSdkException) {
                    val mainResponse = JSONObject().apply {
                      put("id", id)
                      put("error", ex.message ?: "Unknown error")
                    }
                    sendEvent(reactApplicationContext, "onError", mainResponse.toString())
                    promise.reject(id, ex.message, ex)
                  }
                }
              )
            }

            override fun onError(exception: TruvideoSdkException) {
              promise.reject("TruvideoSdkException", exception.message)
            }
          }
        )
      } catch (e: Exception) {
        promise.reject("Exception", e.message)
      }
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
        }catch (e : Exception){
            promise!!.reject("Exception",e.message)
        }
    }


  // ─── Map Helpers ──────────────────────────────────────────────────────────

  fun returnRequestsJson(requests: List<TruvideoSdkMediaFileUploadRequest>): String {
    val jsonArray = JSONArray()
    for (request in requests) {
      jsonArray.put(JSONObject(returnRequest(request)))
    }
    return jsonArray.toString()
  }

    fun returnRequest(request : TruvideoSdkMediaFileUploadRequest) : String{
        return JSONObject().apply {
            put("id", request.id)
            put("filePath", request.filePath)
            put("fileType", request.fileType.name)
            put("createdAt", request.createdAt )
            put("updateAt",request.updatedAt)
            put("tags" , request.tags)
            put("metadata", request.metadata)
            put("durationMilliseconds", request.durationMilliseconds)
          put("remoteId", request.mediaId ?: "")
          put("remoteURL", request.mediaUrl ?: "")
            put("transcriptionURL", request.transcriptionUrl)
            put("status", request.status)
            put("progress", request.uploadProgress)
        }.toString()
    }

    fun builder(filePath: String, tag : String, metaData : String, promise: Promise){
        try{
            val builder = TruvideoSdkMedia.FileUploadRequestBuilder(filePath)
            val jsonTag = JSONObject(tag)
            val keys = jsonTag.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                val value= jsonTag.getString(key)
                builder.addTag(key, value)
            }

            val jsonMetadata = JSONObject(metaData)
            val metadataKeys = jsonMetadata.keys()
            while (metadataKeys.hasNext()) {
                val key = metadataKeys.next()
                val value = jsonMetadata.getString(key)
                builder.addMetadata(key, value)
            }

            builder.build(object:
                TruvideoSdkMediaCallback<TruvideoSdkMediaFileUploadRequest> {
                override fun onComplete(data: TruvideoSdkMediaFileUploadRequest) {
                    val mainResponse = returnRequest(data)
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
                    val mainStatus : TruvideoSdkMediaFileUploadRequestStatus? = when(status) {
                        "UPLOADING" -> TruvideoSdkMediaFileUploadRequestStatus.UPLOADING
                        "IDLE" -> TruvideoSdkMediaFileUploadRequestStatus.IDLE
                        "ERROR" -> TruvideoSdkMediaFileUploadRequestStatus.ERROR
                        "PAUSED" -> TruvideoSdkMediaFileUploadRequestStatus.PAUSED
                        "COMPLETED" -> TruvideoSdkMediaFileUploadRequestStatus.COMPLETED
                        "CANCELED" -> TruvideoSdkMediaFileUploadRequestStatus.CANCELED
                        "SYNCHRONIZING" -> TruvideoSdkMediaFileUploadRequestStatus.SYNCHRONIZING
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
                try {
                    val request = TruvideoSdkMedia.getFileUploadRequestById(id!!)
                    if (request == null) {
                        promise!!.reject("NOT_FOUND", "Upload request not found")
                        return@launch
                    }
                    request.cancel()
                    promise!!.resolve("Cancel Success")
                } catch (e: TruvideoSdkException) {
                    Log.e(NAME, "Cancel error: ${e.message}")
                    promise!!.reject("SDK_ERROR", e.message ?: "Failed to cancel upload")
                }
            }
        }catch (e: Exception){
            promise!!.reject("Exception",e.message)
        }
    }

    @ReactMethod
    fun deleteMedia(id: String?, promise: Promise?) {
        try{
            scope.launch {
                try {
                    val request = TruvideoSdkMedia.getFileUploadRequestById(id!!)
                    if (request == null) {
                        promise!!.reject("NOT_FOUND", "Upload request not found")
                        return@launch
                    }
                    request.delete()
                    promise!!.resolve("Delete Success")
                } catch (e: TruvideoSdkException) {
                    Log.e(NAME, "Delete error: ${e.message}")
                    promise!!.reject("SDK_ERROR", e.message ?: "Failed to delete upload")
                }
            }
        }catch (e: Exception){
            promise!!.reject("Exception",e.message)
        }
    }



  // ─── pauseMedia ───────────────────────────────────────────────────────────

  @ReactMethod
  fun pauseMedia(id: String?, promise: Promise?) {
    try {
      scope.launch {
        val request = TruvideoSdkMedia.getFileUploadRequestById(id!!)
        if (request == null) {
          promise!!.reject("ERROR", "Upload request not found")
          return@launch
        }
        when (request.status) {
          TruvideoSdkMediaFileUploadRequestStatus.UPLOADING -> {
            request.pause()
            promise!!.resolve("Pause Success")
          }
          TruvideoSdkMediaFileUploadRequestStatus.PAUSED -> {
            promise!!.reject("ALREADY_PAUSED", "Upload is already paused")
          }
          TruvideoSdkMediaFileUploadRequestStatus.COMPLETED -> {
            promise!!.reject("COMPLETED", "Upload is already completed")
          }
          else -> {
            promise!!.reject("INVALID_STATE", "Cannot pause. Current status: ${request.status}")
          }
        }
      }
    } catch (e: TruvideoSdkException) {
      promise!!.reject("TruvideoSdkException", e.message)
    } catch (e: Exception) {
      promise!!.reject("Exception", e.message)
    }
  }

  @ReactMethod
  fun resumeMedia(id: String?, promise: Promise?) {
    try {
      scope.launch {
        val request = TruvideoSdkMedia.getFileUploadRequestById(id!!)
        if (request == null) {
          promise!!.reject("ERROR", "Upload request not found")
          return@launch
        }
        when (request.status) {
          TruvideoSdkMediaFileUploadRequestStatus.PAUSED -> {
            request.resume()
            promise!!.resolve("Resume Success")
          }
          TruvideoSdkMediaFileUploadRequestStatus.UPLOADING -> {
            promise!!.reject("ALREADY_UPLOADING", "Upload is already in progress")
          }
          TruvideoSdkMediaFileUploadRequestStatus.COMPLETED -> {
            promise!!.reject("COMPLETED", "Upload is already completed")
          }
          else -> {
            promise!!.reject("INVALID_STATE", "Cannot resume. Current status: ${request.status}. Must be PAUSED.")
          }
        }
      }
    } catch (e: TruvideoSdkException) {
      promise!!.reject("TruvideoSdkException", e.message)
    } catch (e: Exception) {
      promise!!.reject("Exception", e.message)
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
        scope.launch {
            try {
                // ✅ Correct type mapping
                val typeData: TruvideoSdkMediaFileType? = when (type?.uppercase()) {
                    "VIDEO" -> TruvideoSdkMediaFileType.VIDEO
                    "AUDIO" -> TruvideoSdkMediaFileType.AUDIO
                    "PDF"   -> TruvideoSdkMediaFileType.DOCUMENT
                    "IMAGE" -> TruvideoSdkMediaFileType.IMAGE
                    else    -> null
                }

                // ✅ Correct tag parsing
                val tagsList = mutableListOf<TruvideoSdkMediaTags.Entry>()
                try {
                    val jsonTag = JSONObject(tag ?: "{}")
                    val keys = jsonTag.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        tagsList.add(
                            TruvideoSdkMediaTags.Entry(key, jsonTag.getString(key))
                        )
                    }
                } catch (e: JSONException) {
                    Log.e(NAME, "Tag parse error: ${e.message}")
                }

                // ✅ Correct API call
                val resultData = TruvideoSdkMedia.search(
                    tags = TruvideoSdkMediaTags(tagsList),
                    type = typeData,
                    page = page?.toIntOrNull() ?: 0,
                    pageSize = pageSize?.toIntOrNull() ?: 10,
                    isLibrary = null
                )

                val jsonArray = JSONArray()

                resultData?.data?.items?.forEach { item ->
                    val metadataObj = JSONObject(item.metadata.toMap() as Map<*, *>)
                    val tagsObj = JSONObject(item.tags.toMap() as Map<*, *>)

                    jsonArray.put(JSONObject().apply {
                        put("id", item.id)
                        put("createdDate", formatDate(item.createdAt))
                        put("remoteId", item.id)
                        put("uploadedFileURL", item.url)
                        put("metaData", metadataObj)
                        put("tags", tagsObj)
                        put("transcriptionURL", item.transcriptionUrl)
                        put("transcriptionLength", item.transcriptionLength)
                        put("fileType", item.type.name)
                        put("title", item.title)
                        put("duration", item.duration ?: "0")
                        put("isLibrary", item.isLibrary)
                    })
                }

                // ✅ IMPORTANT: same structure as TurboModule
                val responseObject = JSONObject().apply {
                    put("data", jsonArray)
                    put("last", resultData?.data?.last)
                    put("totalElements", resultData?.data?.totalElements)
                    put("totalPages", resultData?.data?.totalPages)
                    put("number", resultData?.data?.page)
                    put("size", resultData?.data?.pageSize)
                }

                // ✅ MUST return on Main thread
                withContext(Dispatchers.Main) {
                    promise?.resolve(responseObject.toString())
                }

            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    promise?.reject("SEARCH_ERROR", e.message, e)
                }
            }
        }
    }

  // ─── searchById ───────────────────────────────────────────────────────────

  @ReactMethod
  fun searchById(id: String, promise: Promise) {
    if (id.isEmpty()) {
      promise.reject("INVALID_ID", "Search ID cannot be empty")
      return
    }

    TruvideoSdkMedia.searchById(
      id = id,
      callback = object : TruvideoSdkMediaCallback<TruvideoSdkMediaResponse<TruvideoSdkMediaModel?>?> {
        override fun onComplete(data: TruvideoSdkMediaResponse<TruvideoSdkMediaModel?>?) {
          scope.launch {
            try {
              if (data == null) {
                withContext(Dispatchers.Main) {
                  promise.reject("NO_DATA", "No data found for ID: $id")
                }
                return@launch
              }

              val metadataObj = JSONObject().apply {
                data.data?.metadata?.toMap()?.forEach { (key, value) -> put(key, value) }
              }
              val tagsObj = JSONObject().apply {
                data.data?.tags?.toMap()?.forEach { (key, value) -> put(key, value) }
              }

              val jsonObject = JSONObject().apply {
                put("id", data.data?.id)
                put("createdDate", formatDate(data.data?.createdAt))
                put("remoteId", data.data?.id)
                put("uploadedFileURL", data.data?.url)
                put("metaData", metadataObj)
                put("tags", tagsObj)
                put("transcriptionURL", data.data?.transcriptionUrl)
                put("transcriptionLength", data.data?.transcriptionLength)
                put("fileType", data.data?.type?.name)
                put("title", data.data?.title)
                put("duration", data.data?.duration ?: "0")
              }

              withContext(Dispatchers.Main) {
                promise.resolve(jsonObject.toString())
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) {
                promise.reject("SEARCH_BY_ID_ERROR", e.message ?: "Unknown error")
              }
            }
          }
        }

        override fun onError(exception: TruvideoSdkException) {
          scope.launch {
            withContext(Dispatchers.Main) {
              promise.reject("SEARCH_BY_ID_ERROR", exception.message ?: "Unknown error")
            }
          }
        }
      }
    )
  }

  // ─── Stream Upload — createStreamUploadRequest ────────────────────────────

  @ReactMethod
  fun createStreamUploadRequest(filePath: String?, promise: Promise?) {
    promise!!.reject(
      "NOT_SUPPORTED",
      "Stream upload requests are created by the recording SDK, not by this method. " +
        "Use getAllStreamUploadRequests() to list pending requests after recording."
    )
  }

  // ─── Stream Upload Map Helper ─────────────────────────────────────────────

  private fun mapStreamUploadRequestToJson(request: TruvideoSdkMediaUploadRequest): JSONObject {
    val partsList = JSONArray()
    request.parts.forEach { part ->
      partsList.put(JSONObject().apply {
        put("index", part.index)
        put("createdAt", formatDate(part.createdAt))
        put("updatedAt", formatDate(part.updatedAt))
        put("startedAt", formatDate(part.metrics.startedAt))
        put("endedAt", formatDate(part.metrics.endedAt))
        put("isCompleted", part.metrics.completed)
      })
    }
    return JSONObject().apply {
      put("id", request.id.toString())
      put("title", request.title ?: "")
      put("status", request.status.name)
      put("type", request.type.name)
      put("progress", (request.progress * 100))
      put("thumbnailPath", request.thumbnailPath ?: "")
      put("mediaId", request.mediaId ?: "")
      put("tags", JSONObject(request.tags.toMap() as Map<*, *>))
      put("metadata", JSONObject(request.metadata.toMap() as Map<*, *>))
      put("includeInReport", request.includeInReport)
      put("isLibrary", request.isLibrary)
      put("isStartOperationCompleted", request.fileUploadMetrics.completed)
      put("startOperationStartedAt", formatDate(request.fileUploadMetrics.startedAt))
      put("startOperationEndedAt", formatDate(request.fileUploadMetrics.endedAt))
      put("isCompleteOperationCompleted", request.completionMetrics.completed)
      put("completeOperationStartedAt", formatDate(request.completionMetrics.startedAt))
      put("completeOperationEndedAt", formatDate(request.completionMetrics.endedAt))
      put("parts", partsList)
      put("createdAt", formatDate(request.createdAt))
      put("updatedAt", formatDate(request.updatedAt))
      put("startedAt", formatDate(request.fileUploadMetrics.startedAt))
      put("endedAt", formatDate(request.completionMetrics.endedAt))
    }
  }

  // ─── JSON → Tags / Metadata helpers ──────────────────────────────────────

  private fun buildTagsFromJson(jsonStr: String): TruvideoSdkMediaTags {
    val entries = mutableListOf<TruvideoSdkMediaTags.Entry>()
    try {
      val json = JSONObject(jsonStr)
      json.keys().forEach { key ->
        entries.add(TruvideoSdkMediaTags.Entry(key, json.getString(key)))
      }
    } catch (_: JSONException) { }
    return TruvideoSdkMediaTags(entries)
  }

  private fun buildMetadataFromJson(jsonStr: String): TruvideoSdkMediaMetadata {
    val builder = TruvideoSdkMediaMetadata.builder()
    try {
      val json = JSONObject(jsonStr)
      json.keys().forEach { key ->
        builder.set(key, json.getString(key))
      }
    } catch (_: JSONException) { }
    return builder.build()
  }
  // ─── Stream Upload — getAllStreamUploadRequests ───────────────────────────

  @ReactMethod
  fun getAllStreamUploadRequests(promise: Promise?) {
    scope.launch {
      try {
        val requests = TruvideoSdkMedia.getAllUploadRequests()
        val jsonArray = JSONArray()
        requests.forEach { request ->
          jsonArray.put(mapStreamUploadRequestToJson(request))
        }
        withContext(Dispatchers.Main) {
          promise!!.resolve(jsonArray.toString())
        }
      } catch (e: TruvideoSdkException) {
        withContext(Dispatchers.Main) {
          promise!!.reject("TruvideoSdkException", e.message)
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          promise!!.reject("Exception", e.message)
        }
      }
    }
  }

  // ─── Stream Upload — getStreamUploadRequestById ───────────────────────────

  @ReactMethod
  fun getStreamUploadRequestById(id: String?, promise: Promise?) {
    val longId = id?.toLongOrNull()
    if (longId == null) {
      promise!!.reject("INVALID_ID", "Stream upload request ID must be a valid numeric (Long) value")
      return
    }
    scope.launch {
      try {
        val request = TruvideoSdkMedia.getUploadRequestById(longId)
        withContext(Dispatchers.Main) {
          if (request == null) {
            promise!!.resolve("{}")
          } else {
            promise!!.resolve(mapStreamUploadRequestToJson(request).toString())
          }
        }
      } catch (e: TruvideoSdkException) {
        withContext(Dispatchers.Main) {
          promise!!.reject("TruvideoSdkException", e.message)
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          promise!!.reject("Exception", e.message)
        }
      }
    }
  }

  // ─── Stream Upload — uploadStreamUploadRequest ────────────────────────────

  @ReactMethod
  fun uploadStreamUploadRequest(
    id: String?,
    title: String?,
    tags: String?,
    metadata: String?,
    includeInReport: Boolean,
    isLibrary: Boolean,
    promise: Promise?
  ) {
    val longId = id?.toLongOrNull()
    if (longId == null) {
      promise!!.reject("INVALID_ID", "Stream upload request ID must be a valid numeric (Long) value")
      return
    }
    scope.launch {
      try {
        val request = TruvideoSdkMedia.getUploadRequestById(longId)
        if (request == null) {
          withContext(Dispatchers.Main) {
            promise!!.reject("NOT_FOUND", "Stream upload request not found for id: $id")
          }
          return@launch
        }
        val tagsObj = buildTagsFromJson(tags ?: "{}")
        val metadataObj = buildMetadataFromJson(metadata ?: "{}")
        request.upload(
          title = title ?: "",
          tags = tagsObj,
          metadata = metadataObj,
          includeInReport = includeInReport,
          isLibrary = isLibrary
        )
        withContext(Dispatchers.Main) {
          promise!!.resolve("Stream upload started")
        }
      } catch (e: TruvideoSdkException) {
        withContext(Dispatchers.Main) {
          promise!!.reject("TruvideoSdkException", e.message)
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          promise!!.reject("Exception", e.message)
        }
      }
    }
  }

  // ─── Stream Upload — pauseStreamUploadRequest ─────────────────────────────

  @ReactMethod
  fun pauseStreamUploadRequest(id: String?, promise: Promise?) {
    val longId = id?.toLongOrNull()
    if (longId == null) {
      promise!!.reject("INVALID_ID", "Stream upload request ID must be a valid numeric (Long) value")
      return
    }
    scope.launch {
      try {
        val request = TruvideoSdkMedia.getUploadRequestById(longId)
        if (request == null) {
          withContext(Dispatchers.Main) {
            promise!!.reject("NOT_FOUND", "Stream upload request not found for id: $id")
          }
          return@launch
        }
        request.pause()
        withContext(Dispatchers.Main) {
          promise!!.resolve("Stream paused")
        }
      } catch (e: TruvideoSdkException) {
        withContext(Dispatchers.Main) {
          promise!!.reject("TruvideoSdkException", e.message)
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          promise!!.reject("Exception", e.message)
        }
      }
    }
  }

  // ─── Stream Upload — resumeStreamUploadRequest ────────────────────────────

  @ReactMethod
  fun resumeStreamUploadRequest(id: String?, promise: Promise?) {
    val longId = id?.toLongOrNull()
    if (longId == null) {
      promise!!.reject("INVALID_ID", "Stream upload request ID must be a valid numeric (Long) value")
      return
    }
    scope.launch {
      try {
        val request = TruvideoSdkMedia.getUploadRequestById(longId)
        if (request == null) {
          withContext(Dispatchers.Main) {
            promise!!.reject("NOT_FOUND", "Stream upload request not found for id: $id")
          }
          return@launch
        }
        request.resume()
        withContext(Dispatchers.Main) {
          promise!!.resolve("Stream resumed")
        }
      } catch (e: TruvideoSdkException) {
        withContext(Dispatchers.Main) {
          promise!!.reject("TruvideoSdkException", e.message)
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          promise!!.reject("Exception", e.message)
        }
      }
    }
  }

  // ─── Stream Upload — retryStreamUploadRequest ─────────────────────────────

  @ReactMethod
  fun retryStreamUploadRequest(id: String?, promise: Promise?) {
    val longId = id?.toLongOrNull()
    if (longId == null) {
      promise!!.reject("INVALID_ID", "Stream upload request ID must be a valid numeric (Long) value")
      return
    }
    scope.launch {
      try {
        val request = TruvideoSdkMedia.getUploadRequestById(longId)
        if (request == null) {
          withContext(Dispatchers.Main) {
            promise!!.reject("NOT_FOUND", "Stream upload request not found for id: $id")
          }
          return@launch
        }
        request.retry()
        withContext(Dispatchers.Main) {
          promise!!.resolve("Stream retried")
        }
      } catch (e: TruvideoSdkException) {
        withContext(Dispatchers.Main) {
          promise!!.reject("TruvideoSdkException", e.message)
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          promise!!.reject("Exception", e.message)
        }
      }
    }
  }

  // ─── Stream Upload — deleteStreamUploadRequest ────────────────────────────

  @ReactMethod
  fun deleteStreamUploadRequest(id: String?, promise: Promise?) {
    val longId = id?.toLongOrNull()
    if (longId == null) {
      promise!!.reject("INVALID_ID", "Stream upload request ID must be a valid numeric (Long) value")
      return
    }
    scope.launch {
      try {
        val request = TruvideoSdkMedia.getUploadRequestById(longId)
        if (request == null) {
          withContext(Dispatchers.Main) {
            promise!!.reject("NOT_FOUND", "Stream upload request not found for id: $id")
          }
          return@launch
        }
        request.delete()
        withContext(Dispatchers.Main) {
          promise!!.resolve("Stream deleted")
        }
      } catch (e: TruvideoSdkException) {
        withContext(Dispatchers.Main) {
          promise!!.reject("TruvideoSdkException", e.message)
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          promise!!.reject("Exception", e.message)
        }
      }
    }
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
