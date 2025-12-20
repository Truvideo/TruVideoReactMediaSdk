import Combine
import TruvideoSdkMedia
import React

@objc(TruVideoReactMediaSdk)
class TruVideoReactMediaSdk: RCTEventEmitter {
    override func supportedEvents() -> [String]! {
        return ["onProgress", "onComplete", "onError"]
    }
    
    override static func requiresMainQueueSetup() -> Bool {
        return false
    }
    
    private var disposeBag = Set<AnyCancellable>()
    
    // Add helper function for status conversion
    private func convertStatusToString(_ status: TruvideoSdkMediaUploadRequest.Status) -> String {
        switch status {
        case .idle: return "IDLE"
        case .processing: return "UPLOADING"
        case .completed: return "COMPLETED"
        case .cancelled: return "CANCELED"
        case .paused: return "PAUSED"
        case .error: return "ERROR"
        case .synchronizing: return "SYNCHRONIZING"
        @unknown default: return "IDLE"
        }
    }
    
    // Helper function to detect file type from file path
    private func detectFileType(from filePath: String) -> String {
        let lowercasedPath = filePath.lowercased()
        
        // Video extensions
        if lowercasedPath.hasSuffix(".mp4") || lowercasedPath.hasSuffix(".mov") ||
           lowercasedPath.hasSuffix(".m4v") || lowercasedPath.hasSuffix(".avi") ||
           lowercasedPath.hasSuffix(".mkv") || lowercasedPath.hasSuffix(".wmv") {
            return "VIDEO"
        }
        
        // Image extensions
        if lowercasedPath.hasSuffix(".jpg") || lowercasedPath.hasSuffix(".jpeg") ||
           lowercasedPath.hasSuffix(".png") || lowercasedPath.hasSuffix(".gif") ||
           lowercasedPath.hasSuffix(".heic") || lowercasedPath.hasSuffix(".webp") {
            return "IMAGE"
        }
        
        return "FILE"
    }
    
    @objc(uploadMedia:withTag:withMetaData:withResolver:withRejecter:)
    func uploadMedia(filePath: String, tag: String, metaData: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let fileURL = URL(string: "file://\(filePath)") else {
            reject("INVALID_URL", "The file URL is invalid", nil)
            return
        }

        do {
            let builder = try createFileUploadRequestBuilder(fileURL: fileURL, tag: tag, metaData: metaData)
            try executeUploadRequest(builder: builder, resolve: resolve, reject: reject)
        } catch {
            reject("UPLOAD_ERROR", "Upload failed", error)
        }
    }
    
    @objc(uploadMediaById:withResolver:withRejecter:)
    public func uploadMediaById(id: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let request = try? TruvideoSdkMedia.getFileUploadRequest(withId: id) else {
            reject("REQUEST_NOT_FOUND", "Upload request not found", nil)
            return
        }

        let completeCancellable = request.completionHandler
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] receiveCompletion in
                switch receiveCompletion {
                case .finished:
                    print("Upload finished")
                case .failure(let error):
                    print("Upload failure:", error)
                    reject("UPLOAD_ERROR", "Upload failed", error)
                    self?.sendEvent(withName: "onError", body: error.localizedDescription)
                }
            }, receiveValue: { [weak self] uploadedResult in
                let uploadedFileURL = uploadedResult.uploadedFileURL
                let metadataDict = uploadedResult.metadata
                let tags = uploadedResult.tags
                let transcriptionURL = uploadedResult.transcriptionURL
                let transcriptionLength = uploadedResult.transcriptionLength
                let requestId = request.id.uuidString
                
                print("uploadedResult: ", uploadedResult)
                print("tags: ", tags.dictionary)
                print("metaData: ", metadataDict.dictionary)
                
                let dateFormatter = ISO8601DateFormatter()
                
                do {
                    let mainResponse: [String: Any] = [
                        "id": requestId,
                        "createdDate": dateFormatter.string(from: uploadedResult.createdDate),
                        "remoteId": uploadedResult.remoteId,
                        "uploadedFileURL": uploadedFileURL.absoluteString,
                        "metaData": metadataDict.dictionary,
                        "tags": tags.dictionary,
                        "transcriptionURL": transcriptionURL?.absoluteString ?? "",
                        "transcriptionLength": "\(transcriptionLength)",
                        "fileType": uploadedResult.type.rawValue,
                    ]
                    
                    let jsonData = try JSONSerialization.data(withJSONObject: mainResponse, options: [])
                    
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print("mainResponse as JSON string: \(jsonString)")
                        resolve(jsonString)
                        self?.sendEvent(withName: "onComplete", body: jsonString)
                    } else {
                        print("Error: Could not convert JSON data to string.")
                        reject("INVALID_JSON", "Error: Could not convert JSON data to string", nil)
                    }
                } catch {
                    reject("INVALID_JSON", "Error: Could not convert JSON data to string", nil)
                }
            })

        completeCancellable.store(in: &disposeBag)

        let progress = request.progressHandler
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] progress in
                let mainResponse: [String: String] = [
                    "id": id,
                    "progress": String(format: "%.2f%%", progress.percentage * 100)
                ]
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: mainResponse, options: [])
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        self?.sendEvent(withName: "onProgress", body: jsonString)
                    } else {
                        self?.sendEvent(withName: "onProgress", body: "Unable to Parse JSON")
                    }
                } catch {
                    self?.sendEvent(withName: "onProgress", body: "Unable to Parse JSON")
                }
            })

        progress.store(in: &disposeBag)

        try? request.upload()
    }

    private func createFileUploadRequestBuilder(fileURL: URL, tag: String, metaData: String) throws -> TruvideoSdkMedia.FileUploadRequestBuilder {
        let builder = TruvideoSdkMedia.FileUploadRequestBuilder(fileURL: fileURL)

        let tagDict = try convertToDictionary(from: tag)
        for (key, value) in tagDict {
            builder.addTag(key, "\(value)")
        }

        let metadataObj = try convertToDictionary(from: metaData)
        for (key, value) in metadataObj {
            builder.addMetadata(key, "\(value)")
        }
        return builder
    }

    private func executeUploadRequest(builder: TruvideoSdkMedia.FileUploadRequestBuilder, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) throws {
        let request = try builder.build()

        print("fileUploadRequest: ", request.id.uuidString)

        let completeCancellable = request.completionHandler
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] receiveCompletion in
                switch receiveCompletion {
                case .finished:
                    print("Upload finished")
                case .failure(let error):
                    print("Upload failure:", error)
                    reject("UPLOAD_ERROR", "Upload failed", error)
                    self?.sendEvent(withName: "onError", body: error.localizedDescription)
                }
            }, receiveValue: { [weak self] uploadedResult in
                let uploadedFileURL = uploadedResult.uploadedFileURL
                let metadataDict = uploadedResult.metadata
                let tags = uploadedResult.tags
                let transcriptionURL = uploadedResult.transcriptionURL
                let transcriptionLength = uploadedResult.transcriptionLength
                let id = request.id.uuidString
                
                print("uploadedResult: ", uploadedResult)
                print("tags: ", tags.dictionary)
                print("metaData: ", metadataDict.dictionary)
                
                let mainResponse: [String: Any] = [
                    "id": id,
                    "uploadedFileURL": uploadedFileURL.absoluteString,
                    "metaData": metadataDict.dictionary,
                    "tags": tags.dictionary,
                    "transcriptionURL": transcriptionURL?.absoluteString ?? "",
                    "transcriptionLength": transcriptionLength
                ]

                resolve(["status": mainResponse])
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: mainResponse, options: [])
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        self?.sendEvent(withName: "onComplete", body: jsonString)
                    }
                } catch {
                    print("Failed to serialize completion response")
                }
            })

        completeCancellable.store(in: &disposeBag)

        let progress = request.progressHandler
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] progress in
                let mainResponse: [String: Any] = [
                    "id": UUID().uuidString,
                    "progress": String(format: "%.2f%%", progress.percentage * 100)
                ]
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: mainResponse, options: [])
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        self?.sendEvent(withName: "onProgress", body: jsonString)
                    }
                } catch {
                    print("Failed to serialize progress")
                }
            })

        progress.store(in: &disposeBag)

        try request.upload()
    }

    private func convertToDictionary(from jsonString: String) throws -> [String: Any] {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "Invalid JSON string", code: 0, userInfo: nil)
        }

        guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            throw NSError(domain: "Invalid JSON format", code: 1, userInfo: nil)
        }

        return jsonObject
    }

    private func convertToJsonString(from dictionary: [String: Any]) throws -> String {
        let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])

        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "Unable to encode JSON string", code: 2, userInfo: nil)
        }

        return jsonString
    }

    @objc(mediaBuilder:withTag:withMetaData:withResolver:withRejecter:)
    public func mediaBuilder(filePath: String, tag: String, metaData: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let fileURL = URL(string: "file://\(filePath)") else {
            reject("INVALID_URL", "The file URL is invalid", nil)
            return
        }

        do {
            let builder = try createFileUploadRequestBuilder(fileURL: fileURL, tag: tag, metaData: metaData)
            let request = try builder.build()
            
            let dateFormatter = ISO8601DateFormatter()
            var tagString = ""
            let tagJsonData = try JSONSerialization.data(withJSONObject: request.tags.dictionary, options: [])
            if let tagJsonString = String(data: tagJsonData, encoding: .utf8) {
                tagString = tagJsonString
            }
            
            var metadataString = ""
            let metadataJsonData = try JSONSerialization.data(withJSONObject: request.metadata.dictionary, options: [])
            if let metadataJsonString = String(data: metadataJsonData, encoding: .utf8) {
                metadataString = metadataJsonString
            }
            
            // Detect file type from file path
            let fileType = detectFileType(from: request.filePath)
            
            let mainResponse: [String: Any] = [
                "id": request.id.uuidString,
                "filePath": request.filePath,
                "fileType": fileType,
                "createdAt": request.createdAt != nil ? dateFormatter.string(from: request.createdAt!) : "",
                "updatedAt": request.updatedAt != nil ? dateFormatter.string(from: request.updatedAt!) : "",
                "tags": tagString,
                "metadata": metadataString,
                "remoteId": request.remoteId ?? "",
                "remoteURL": request.remoteURL?.absoluteString ?? "",
                "transcriptionURL": request.transcriptionURL ?? "",
                "status": convertStatusToString(request.status),
                "progress": "\(request.uploadProgress)"
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: mainResponse, options: [])

            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("mainResponse as JSON string: \(jsonString)")
                resolve(jsonString)
            } else {
                print("Error: Could not convert JSON data to string.")
                reject("JSON_ERROR", "Could not convert JSON data to string", nil)
            }
        } catch {
            reject("UPLOAD_ERROR", "Upload failed", error)
        }
    }

    @objc(getFileUploadRequestById:withResolver:withRejecter:)
    public func getFileUploadRequestById(id: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do {
            let request = try TruvideoSdkMedia.getFileUploadRequest(withId: id)
            let dateFormatter = ISO8601DateFormatter()
            
            var tagString = ""
            let tagJsonData = try JSONSerialization.data(withJSONObject: request.tags.dictionary, options: [])
            if let tagJsonString = String(data: tagJsonData, encoding: .utf8) {
                tagString = tagJsonString
            }
            
            var metadataString = ""
            let metadataJsonData = try JSONSerialization.data(withJSONObject: request.metadata.dictionary, options: [])
            if let metadataJsonString = String(data: metadataJsonData, encoding: .utf8) {
                metadataString = metadataJsonString
            }
            
            // Detect file type from file path
            let fileType = detectFileType(from: request.filePath)
            
            let mainResponse: [String: Any] = [
                "id": request.id.uuidString,
                "filePath": request.filePath,
                "fileType": fileType,
                "createdAt": request.createdAt != nil ? dateFormatter.string(from: request.createdAt!) : "",
                "updatedAt": request.updatedAt != nil ? dateFormatter.string(from: request.updatedAt!) : "",
                "tags": tagString,
                "metadata": metadataString,
                "remoteId": request.remoteId ?? "",
                "remoteURL": request.remoteURL?.absoluteString ?? "",
                "transcriptionURL": request.transcriptionURL ?? "",
                "status": convertStatusToString(request.status),
                "progress": "\(request.uploadProgress)"
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: mainResponse, options: [])

            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("mainResponse as JSON string: \(jsonString)")
                resolve(jsonString)
            } else {
                print("Error: Could not convert JSON data to string.")
                reject("JSON_ERROR", "Could not convert JSON data to string", nil)
            }
        } catch {
            resolve("{}")
        }
    }

    @objc(getAllFileUploadRequests:withResolver:withRejecter:)
    public func getAllFileRequests(status: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do {
            var statusData: TruvideoSdkMediaUploadRequest.Status?
            if status == "COMPLETED" {
                statusData = .completed
            } else if status == "CANCELED" {
                statusData = .cancelled
            } else if status == "PAUSED" {
                statusData = .paused
            } else if status == "SYNCHRONIZING" {
                statusData = .synchronizing
            } else if status == "IDLE" {
                statusData = .idle
            } else if status == "UPLOADING" {
                statusData = .processing
            } else if status == "ERROR" {
                statusData = .error
            } else {
                statusData = nil
            }
            
            let requests = try TruvideoSdkMedia.getFileUploadRequests(byStatus: statusData)
            let dateFormatter = ISO8601DateFormatter()
            var responseArray: [[String: Any]] = []  // Changed to [String: Any]

            for request in requests {
                var tagString = ""
                let tagJsonData = try JSONSerialization.data(withJSONObject: request.tags.dictionary, options: [])
                if let tagJsonString = String(data: tagJsonData, encoding: .utf8) {
                    tagString = tagJsonString
                }

                var metadataString = ""
                let metadataJsonData = try JSONSerialization.data(withJSONObject: request.metadata.dictionary, options: [])
                if let metadataJsonString = String(data: metadataJsonData, encoding: .utf8) {
                    metadataString = metadataJsonString
                }

                // Detect file type from file path
                let fileType = detectFileType(from: request.filePath)

                let mainResponse: [String: Any] = [
                    "id": request.id.uuidString,
                    "filePath": request.filePath,
                    "fileType": fileType,
                    "createdAt": request.createdAt != nil ? dateFormatter.string(from: request.createdAt!) : "",
                    "updatedAt": request.updatedAt != nil ? dateFormatter.string(from: request.updatedAt!) : "",
                    "tags": tagString,
                    "metadata": metadataString,
                    "remoteId": request.remoteId ?? "",
                    "remoteURL": request.remoteURL?.absoluteString ?? "",
                    "transcriptionURL": request.transcriptionURL ?? "",
                    "status": convertStatusToString(request.status),
                    "progress": "\(request.uploadProgress)"
                ]

                responseArray.append(mainResponse)
            }

            let jsonData = try JSONSerialization.data(withJSONObject: responseArray, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("responseArray as JSON string: \(jsonString)")
                resolve(jsonString)
            } else {
                print("Error: Could not convert JSON data to string.")
                reject("JSON_ERROR", "Could not convert JSON data to string", nil)
            }

        } catch {
            resolve("[]")
        }
    }

    @objc(cancelMedia:withResolver:withRejecter:)
    public func cancelMedia(id: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do {
            let request = try TruvideoSdkMedia.getFileUploadRequest(withId: id)
            try request.cancel()
            resolve("Cancel Success")
        } catch {
            reject("CANCEL_ERROR", "Failed to cancel media", error)
        }
    }

    @objc(deleteMedia:withResolver:withRejecter:)
    public func deleteMedia(id: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do {
            let request = try TruvideoSdkMedia.getFileUploadRequest(withId: id)
            try request.delete()
            resolve("Delete Success")
        } catch {
            reject("DELETE_ERROR", "Failed to delete media", error)
        }
    }

    @objc(pauseMedia:withResolver:withRejecter:)
    public func pauseMedia(id: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do {
            let request = try TruvideoSdkMedia.getFileUploadRequest(withId: id)
            try request.pause()
            resolve("Pause Success")
        } catch {
            reject("PAUSE_ERROR", "Failed to pause media", error)
        }
    }

    @objc(resumeMedia:withResolver:withRejecter:)
    public func resumeMedia(id: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do {
            let request = try TruvideoSdkMedia.getFileUploadRequest(withId: id)
            try request.resume()
            resolve("Resume Success")
        } catch {
            reject("RESUME_ERROR", "Failed to resume media", error)
        }
    }

    @objc(search:withType:withPage:withPageSize:withResolver:withRejecter:)
    public func search(tag: String, type: String, page: String, pageSize: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let tagDict = try? convertToDictionary(from: tag) else {
            reject("INVALID_TAG", "Invalid tag JSON", nil)
            return
        }
        
        var tagBuild = TruvideoSdkMediaTags.builder()
        for (key, value) in tagDict {
            _ = tagBuild.set(key, "\(value)")
        }
        
        var typeData: TruvideoSdkMediaType?
        if type == "Image" {
            typeData = .image
        } else if type == "Video" {
            typeData = .video
        } else {
            typeData = nil
        }
        
        Task {
            do {
                let request = try await TruvideoSdkMedia.search(
                    type: typeData,
                    tags: tagBuild.build(),
                    pageNumber: Int(page) ?? 0,
                    size: Int(pageSize) ?? 10
                )
                
                let mediaList = request.content
                
                if mediaList.isEmpty {
                    resolve("[]")
                    return
                }
                
                var list = [String]()
                let dateFormatter = ISO8601DateFormatter()
                
                for media in mediaList {
                    let mediaDict: [String: Any] = [
                        "id": media.remoteId,
                        "createdDate": dateFormatter.string(from: media.createdDate),
                        "remoteId": media.remoteId,
                        "uploadedFileURL": media.uploadedFileURL.absoluteString,
                        "metaData": media.metadata.dictionary,
                        "tags": media.tags.dictionary,
                        "transcriptionURL": media.transcriptionURL?.absoluteString ?? "",
                        "transcriptionLength": "\(media.transcriptionLength)",
                        "fileType": media.type.rawValue
                    ]
                    
                    let jsonData = try JSONSerialization.data(withJSONObject: mediaDict, options: [])
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        list.append(jsonString)
                    }
                }
                
                let jsonData = try JSONSerialization.data(withJSONObject: list, options: [])
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    resolve(jsonString)
                } else {
                    reject("ERROR", "JSON_ERROR", nil)
                }
            } catch {
                reject("SEARCH_ERROR", "Search failed", error)
            }
        }
    }
}
