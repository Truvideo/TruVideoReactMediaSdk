import Combine
import TruvideoSdkMedia
import React

@objc(TruVideoReactMediaSdk)
class TruVideoReactMediaSdk: NSObject {
    private var disposeBag = Set<AnyCancellable>()

    @objc(multiply:withB:withResolver:withRejecter:)
    func multiply(a: Float, b: Float, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) -> Void {
        resolve(a * b)
    }

    @objc(uploadMedia:withTag:withMetaData:withResolver:withRejecter:)
    func uploadMedia(filePath: String,tag : String,metaData : String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
        let path = "file://\(filePath)"
        uploadFile(videoPath: path,tag : tag, metaData : metaData, resolve: resolve, reject: reject)
    }

    // Function to send events to React Native
    func sendEvent(withName name: String, body: [String: Any]) {
        guard let bridge = RCTBridge.current() else { return }
        bridge.eventDispatcher().sendAppEvent(withName: name, body: body)
    }
  
    // Function to upload a video file to the cloud
    func uploadFile(videoPath: String,tag : String,metaData : String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let fileURL = URL(string: videoPath) else {
            reject("INVALID_URL", "The file URL is invalid", nil)
            return
        }

        // Media Uploading
        // Create a file upload request using TruvideoSdkMedia uploader
        let builder = TruvideoSdkMedia.FileUploadRequestBuilder(fileURL: fileURL)
        
        // Tags
        builder.addTag("key", "value")
        builder.addTag("color", "red")
        builder.addTag("order-number", "123")
        
        // Metadata
        var metadata = Metadata()
        metadata["key"] = "value"
        metadata["key1"] = 1
        metadata["key2"] = [4, 5, 6]
        builder.setMetadata(metadata)
        
        let request = builder.build()
        
        // Print the file upload request for debugging
        print("fileUploadRequest: ", request.id.uuidString)
        
        // Completion of request
        // Handle the completion of the file upload request
        let completeCancellable = request.completionHandler
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { receiveCompletion in
                switch receiveCompletion {
                case .finished:
                    print("Upload finished")
                case .failure(let error):
                    // Print any errors that occur during the upload process
                    print("Upload failure:", error)
                    reject("UPLOAD_ERROR", "Upload failed", error)
                }
            }, receiveValue: { uploadedResult in
                // Upon successful upload, retrieve the uploaded file URL
                let uploadedFileURL = uploadedResult.uploadedFileURL
                let metaData = uploadedResult.metadata
                let tags = uploadedResult.tags
                let transcriptionURL = uploadedResult.transcriptionURL
               // let type = uploadedResult.type.rawValue
                let transcriptionLength = uploadedResult.transcriptionLength
                let id = request.id.uuidString
                print("uploadedResult: ", uploadedResult)
                
                // Send completion event
                let mainResponse: [String: Any] = [
                    "id": id, // Generate a unique ID for the event
                    "uploadedFileURL": uploadedFileURL.absoluteString,
                    "metaData": metaData,
                    "tags": tags,
                    "transcriptionURL": transcriptionURL,
                    "transcriptionLength": transcriptionLength
                   // "type": type
                ]
                
                // resolve
                resolve(["status": mainResponse])
                self.sendEvent(withName: "onComplete", body: mainResponse)
            })
        
        // Store the completion handler in the dispose bag to avoid premature deallocation
        completeCancellable.store(in: &disposeBag)
        
        // Progress of request
        // Track the progress of the file upload request
        let progress = request.progressHandler
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { progress in
                // Handle progress updates
                let mainResponse: [String: Any] = [
                    "id": UUID().uuidString, // Generate a unique ID for the event
                    "progress": String(format: " %.2f %", progress.percentage * 100)
                ]
               // print("Progress: \(progress)") // Log progress for debugging
                self.sendEvent(withName: "onProgress", body: mainResponse)
            })
        
        // Store the progress handler in the dispose bag to avoid premature deallocation
        progress.store(in: &disposeBag)
        
        do {
            try request.upload()
        } catch {
            // Handle error
            reject("UPLOAD_ERROR", "Upload failed", error)
        }
    }
}
