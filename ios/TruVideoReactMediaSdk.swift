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
            
            let mainResponse: [String: String] = [
                "id": request.id.uuidString,
                "filePath": request.filePath,
                "createdAt": request.createdAt != nil ? dateFormatter.string(from: request.createdAt!) : "",
                "updatedAt": request.updatedAt != nil ? dateFormatter.string(from: request.updatedAt!) : "",
                "tags": tagString,
                "metadata": metadataString,
                "remoteId": request.remoteId ?? "",
                "remoteURL": request.remoteURL?.absoluteString ?? "",
                "transcriptionURL": request.transcriptionURL ?? "",
                "status": "\(request.status.rawValue)",
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
            
            let mainResponse: [String: String] = [
                "id": request.id.uuidString,
                "filePath": request.filePath,
                "createdAt": request.createdAt != nil ? dateFormatter.string(from: request.createdAt!) : "",
                "updatedAt": request.updatedAt != nil ? dateFormatter.string(from: request.updatedAt!) : "",
                "tags": tagString,
                "metadata": metadataString,
                "remoteId": request.remoteId ?? "",
                "remoteURL": request.remoteURL?.absoluteString ?? "",
                "transcriptionURL": request.transcriptionURL ?? "",
                "status": "\(request.status.rawValue)",
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
            var responseArray: [[String: String]] = []

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

                let mainResponse: [String: String] = [
                    "id": request.id.uuidString,
                    "filePath": request.filePath,
                    "createdAt": request.createdAt != nil ? dateFormatter.string(from: request.createdAt!) : "",
                    "updatedAt": request.updatedAt != nil ? dateFormatter.string(from: request.updatedAt!) : "",
                    "tags": tagString,
                    "metadata": metadataString,
                    "remoteId": request.remoteId ?? "",
                    "remoteURL": request.remoteURL?.absoluteString ?? "",
                    "transcriptionURL": request.transcriptionURL ?? "",
                    "status": "\(request.status.rawValue)",
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
  
  // ────────────────────────────────────────────────────────────────────────────
      // STREAM UPLOAD — based on actual TruvideoSdkMediaInterface
      // ────────────────────────────────────────────────────────────────────────────

      @objc public func createStreamUploadRequest(
          _ filePath: String,
          resolve: @escaping RCTPromiseResolveBlock,
          reject: @escaping RCTPromiseRejectBlock
      ) {
          guard let fileURL = URL(string: "file://\(filePath)") else {
              reject("INVALID_URL", "The file URL is invalid", nil)
              return
          }
          Task {
              do {
                  let request = try await TruvideoSdkMedia.createUploadRequest(from: fileURL)
                  let dict = mapStreamRequestToDict(request)
                  let jsonData = try JSONSerialization.data(withJSONObject: dict)
                  resolve(String(data: jsonData, encoding: .utf8) ?? "{}")
              } catch {
                  reject("CREATE_ERROR", error.localizedDescription, error)
              }
          }
      }

      @objc public func getAllStreamUploadRequests(
          _ resolve: @escaping RCTPromiseResolveBlock,
          reject: @escaping RCTPromiseRejectBlock
      ) {
          Task {
              do {
                  let requests = try await TruvideoSdkMedia.getAllUploadRequests()
                  let list = requests.map { mapStreamRequestToDict($0) }
                  let jsonData = try JSONSerialization.data(withJSONObject: list)
                  resolve(String(data: jsonData, encoding: .utf8) ?? "[]")
              } catch {
                  resolve("[]")
              }
          }
      }

      @objc public func getStreamUploadRequestById(
          _ id: String,
          resolve: @escaping RCTPromiseResolveBlock,
          reject: @escaping RCTPromiseRejectBlock
      ) {
          Task {
              do {
                  let request = try await TruvideoSdkMedia.getUploadRequestById(id)
                  let dict = mapStreamRequestToDict(request)
                  if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                     let jsonString = String(data: jsonData, encoding: .utf8) {
                      resolve(jsonString)
                  } else {
                      resolve("{}")
                  }
              } catch {
                  resolve("{}")
              }
          }
      }
      @objc public func uploadStreamUploadRequest(
          _ id: String,
          title: String,
          tags: String,
          metadata: String,
          includeInReport: Bool,
          isLibrary: Bool,
          resolve: @escaping RCTPromiseResolveBlock,
          reject: @escaping RCTPromiseRejectBlock
      ) {
          Task {
              do {
                  let request = try await TruvideoSdkMedia.getUploadRequestById(id)
                  let status = normalizeStreamRequestStatus(request.status)

                  if ["PROCESSING", "PAUSED", "COMPLETED"].contains(status) {
                      let dict = mapStreamRequestToDict(request)
                      if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                         let jsonString = String(data: jsonData, encoding: .utf8) {
                          resolve(jsonString)
                      } else {
                          resolve("{}")
                      }
                      return
                  }

                  // Build tags from JSON string
                  let tagsDict = (try? convertToDictionary(from: tags)) ?? [:]
                  var tagsBuilder = TruvideoSdkMediaTags.builder()
                  for (key, value) in tagsDict {
                      tagsBuilder = tagsBuilder.set(key, "\(value)")
                  }

                  // Build metadata from JSON string
                  let metadataDict = (try? convertToDictionary(from: metadata)) ?? [:]
                  let metadataBuilder = TruvideoSdkMediaMetadata.builder()
                  for (key, value) in metadataDict {
                      _ = metadataBuilder.set(key, "\(value)")
                  }

                  // Use the Options struct — this is the correct iOS API
                  let options = TruvideoSdkMediaStreamRequest.Options(
                      isIncludedInReport: includeInReport,
                      isLibrary: isLibrary,
                      metadata: metadataBuilder.build(),
                      tags: tagsBuilder.build().dictionary,
                      title: title
                  )

                  try request.upload(with: options)
                  let initialResponse = mapStreamRequestToDict(request)
                  if let jsonData = try? JSONSerialization.data(withJSONObject: initialResponse),
                     let jsonString = String(data: jsonData, encoding: .utf8) {
                      resolve(jsonString)
                  } else {
                      resolve("{}")
                  }

                  let completeCancellable = request.completionHandler
                      .receive(on: DispatchQueue.main)
                      .sink(receiveCompletion: { completion in
                          switch completion {
                          case .finished:
                              break
                          case .failure(let error):
                              self.sendEvent(withName: "onError", body: error.localizedDescription)
                          }
                      }, receiveValue: { remoteId in
                          let responseDict: [String: Any] = [
                              "id": id,
                              "remoteId": remoteId,
                              "status": "uploaded"
                          ]
                          if let jsonData = try? JSONSerialization.data(withJSONObject: responseDict),
                             let jsonString = String(data: jsonData, encoding: .utf8) {
                              self.sendEvent(withName: "onComplete", body: jsonString)
                          }
                      })
                  completeCancellable.store(in: &disposeBag)

              } catch {
                  reject("STREAM_UPLOAD_ERROR", error.localizedDescription, error)
              }
          }
      }

      @objc public func pauseStreamUploadRequest(
          _ id: String,
          resolve: @escaping RCTPromiseResolveBlock,
          reject: @escaping RCTPromiseRejectBlock
      ) {
          Task {
              do {
                  let request = try await TruvideoSdkMedia.getUploadRequestById(id)
                  try await request.pause()
                  resolve("Stream paused")
              } catch {
                  reject("STREAM_PAUSE_ERROR", error.localizedDescription, error)
              }
          }
      }

      @objc public func resumeStreamUploadRequest(
          _ id: String,
          resolve: @escaping RCTPromiseResolveBlock,
          reject: @escaping RCTPromiseRejectBlock
      ) {
          Task {
              do {
                  let request = try await TruvideoSdkMedia.getUploadRequestById(id)
                  try await request.resume()
                  resolve("Stream resumed")
              } catch {
                  reject("STREAM_RESUME_ERROR", error.localizedDescription, error)
              }
          }
      }

      @objc public func retryStreamUploadRequest(
          _ id: String,
          resolve: @escaping RCTPromiseResolveBlock,
          reject: @escaping RCTPromiseRejectBlock
      ) {
          Task {
              do {
                  let request = try await TruvideoSdkMedia.getUploadRequestById(id)
                  try await request.retry()
                  resolve("Stream retried")
              } catch {
                  reject("STREAM_RETRY_ERROR", error.localizedDescription, error)
              }
          }
      }

      @objc public func deleteStreamUploadRequest(
          _ id: String,
          resolve: @escaping RCTPromiseResolveBlock,
          reject: @escaping RCTPromiseRejectBlock
      ) {
          Task {
              do {
                  let request = try await TruvideoSdkMedia.getUploadRequestById(id)
                  try await request.delete()
                  resolve("Stream deleted")
              } catch {
                  reject("STREAM_DELETE_ERROR", error.localizedDescription, error)
              }
          }
      }

      @objc public func searchById(
          _ id: String,
          resolve: @escaping RCTPromiseResolveBlock,
          reject: @escaping RCTPromiseRejectBlock
      ) {
          Task {
              do {
                  // getById is the correct method per swiftinterface
                  guard let media = try await TruvideoSdkMedia.getById(id) else {
                      resolve("{}")
                      return
                  }
                  let dateFormatter = ISO8601DateFormatter()
                  let tagJsonData = try JSONSerialization.data(withJSONObject: media.tags.dictionary)
                  let tagString = String(data: tagJsonData, encoding: .utf8) ?? "{}"

                  let metaJsonData = try JSONSerialization.data(withJSONObject: media.metadata.dictionary)
                  let metaString = String(data: metaJsonData, encoding: .utf8) ?? "{}"

                  let dict: [String: Any] = [
                      "id": media.remoteId,
                      "createdDate": dateFormatter.string(from: media.createdDate),
                      "remoteId": media.remoteId,
                      "uploadedFileURL": media.uploadedFileURL.absoluteString,
                      "metaData": metaString,
                      "tags": tagString,
                      "transcriptionURL": media.transcriptionURL?.absoluteString ?? "",
                      "transcriptionLength": "\(media.transcriptionLength)",
                      "fileType": media.type.rawValue,
                      "thumbnailUrl": media.thumbnailUrl?.absoluteString ?? "",
                      "previewUrl": media.previewUrl?.absoluteString ?? ""
                  ]
                  let jsonData = try JSONSerialization.data(withJSONObject: dict)
                  resolve(String(data: jsonData, encoding: .utf8) ?? "{}")
              } catch {
                  reject("SEARCH_BY_ID_ERROR", error.localizedDescription, error)
              }
          }
      }

      // ────────────────────────────────────────────────────────────────────────────
      // Helper — maps TruvideoSdkMediaStreamRequest to Dict
      // ────────────────────────────────────────────────────────────────────────────
      private func normalizeStreamRequestStatus(_ status: TruvideoSdkMediaStreamRequest.Status) -> String {
          switch status {
          case .cancelled:
              return "CANCELED"
          case .error:
              return "ERROR"
          case .paused:
              return "PAUSED"
          case .pending:
              return "IDLE"
          case .processing:
              return "PROCESSING"
          case .uploaded:
              return "COMPLETED"
          }
      }

      private func mapStreamRequestToDict(_ request: TruvideoSdkMediaStreamRequest) -> [String: Any] {
          let dateFormatter = ISO8601DateFormatter()
          return [
              "id": request.id.uuidString,
              "status": normalizeStreamRequestStatus(request.status),
              "type": request.fileType.rawValue,
              "progress": 0,
              "thumbnailPath": "",
              "mediaId": request.remoteId ?? "",
              "createdAt": dateFormatter.string(from: request.createdAt),
              "updatedAt": dateFormatter.string(from: request.createdAt),
              "filePath": request.fileUrl.absoluteString,
              "fileUrl": request.fileUrl.absoluteString,
              "isLibrary": request.isLibrary,
              "includeInReport": request.isIncludedInReport,
              "isIncludedInReport": request.isIncludedInReport,
              "tags": request.tags.dictionary,
              "metadata": request.metadata.dictionary,
              "durationMilliseconds": request.durationMilliseconds ?? 0,
              "parts": [],
          ]
      }
      
      // ────────────────────────────────────────────────────────────────────────────
      // AsyncStream bridges — push live status updates to JS via events
      // ────────────────────────────────────────────────────────────────────────────

      // Holds running stream tasks so we can cancel them
      private var streamAllTask: Task<Void, Never>? = nil
      private var streamByIdTasks: [String: Task<Void, Never>] = [:]

      @objc public func startStreamAllUploadRequests() {
          streamAllTask?.cancel()
          streamAllTask = Task {
              let stream = TruvideoSdkMedia.streamAllUploadRequests()
              for await requests in stream {
                  if Task.isCancelled { break }
                  let list = requests.map { mapStreamRequestToDict($0) }
                  if let jsonData = try? JSONSerialization.data(withJSONObject: list),
                     let jsonString = String(data: jsonData, encoding: .utf8) {
                      sendEvent(withName: "onStreamAllUploadRequests", body: jsonString)
                  }
              }
          }
      }

      @objc public func stopStreamAllUploadRequests() {
          streamAllTask?.cancel()
          streamAllTask = nil
      }

      @objc public func startStreamUploadRequestById(_ id: String) {
          streamByIdTasks[id]?.cancel()
          streamByIdTasks[id] = Task {
              let stream = TruvideoSdkMedia.streamUploadRequestById(id)
              for await request in stream {
                  if Task.isCancelled { break }
                  let dict = mapStreamRequestToDict(request)
                  if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                     let jsonString = String(data: jsonData, encoding: .utf8) {
                      sendEvent(withName: "onStreamUploadRequestById", body: jsonString)
                  }
              }
          }
      }

      @objc public func stopStreamUploadRequestById(_ id: String) {
          streamByIdTasks[id]?.cancel()
          streamByIdTasks[id] = nil
      }
  
  // Function to send events to React Native
      private func sendEvent(withName name: String, body: String) {
          guard let bridge = RCTBridge.current() else { return }
          bridge.eventDispatcher().sendAppEvent(withName: name, body: body)
      }
}
