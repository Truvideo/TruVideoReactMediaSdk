#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(TruVideoReactMediaSdk, RCTEventEmitter)

// Upload media from file path
RCT_EXTERN_METHOD(uploadMedia:(NSString *)filePath
                 withTag:(NSString *)tag
                 withMetaData:(NSString *)metaData
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

// Upload media by ID
RCT_EXTERN_METHOD(uploadMediaById:(NSString *)id
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

// Create media builder
RCT_EXTERN_METHOD(mediaBuilder:(NSString *)filePath
                 withTag:(NSString *)tag
                 withMetaData:(NSString *)metaData
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

// Get file upload request by ID
RCT_EXTERN_METHOD(getFileUploadRequestById:(NSString *)id
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

// Get all file requests
RCT_EXTERN_METHOD(getAllFileUploadRequests:(NSString *)status
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

// Cancel media
RCT_EXTERN_METHOD(cancelMedia:(NSString *)id
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

// Delete media
RCT_EXTERN_METHOD(deleteMedia:(NSString *)id
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

// Pause media
RCT_EXTERN_METHOD(pauseMedia:(NSString *)id
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

// Resume media
RCT_EXTERN_METHOD(resumeMedia:(NSString *)id
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

// Search media
RCT_EXTERN_METHOD(search:(NSString *)tag
                 withType:(NSString *)type
                 withPage:(NSString *)page
                 withPageSize:(NSString *)pageSize
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

// Search by remote ID
RCT_EXTERN_METHOD(searchById:(NSString *)id
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

// Create stream upload request
RCT_EXTERN_METHOD(createStreamUploadRequest:(NSString *)filePath
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

// Get all stream upload requests
RCT_EXTERN_METHOD(getAllStreamUploadRequests:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

// Get stream upload request by ID
RCT_EXTERN_METHOD(getStreamUploadRequestById:(NSString *)id
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

// Upload stream upload request
RCT_EXTERN_METHOD(uploadStreamUploadRequest:(NSString *)id
                 title:(NSString *)title
                 tags:(NSString *)tags
                 metadata:(NSString *)metadata
                 includeInReport:(BOOL)includeInReport
                 isLibrary:(BOOL)isLibrary
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

// Pause stream upload request
RCT_EXTERN_METHOD(pauseStreamUploadRequest:(NSString *)id
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

// Resume stream upload request
RCT_EXTERN_METHOD(resumeStreamUploadRequest:(NSString *)id
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

// Retry stream upload request
RCT_EXTERN_METHOD(retryStreamUploadRequest:(NSString *)id
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

// Delete stream upload request
RCT_EXTERN_METHOD(deleteStreamUploadRequest:(NSString *)id
                 resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject)

// Start streaming all upload requests (AsyncStream → JS events)
RCT_EXTERN_METHOD(startStreamAllUploadRequests)

// Stop streaming all upload requests
RCT_EXTERN_METHOD(stopStreamAllUploadRequests)

// Start streaming a single upload request by ID
RCT_EXTERN_METHOD(startStreamUploadRequestById:(NSString *)id)

// Stop streaming a single upload request by ID
RCT_EXTERN_METHOD(stopStreamUploadRequestById:(NSString *)id)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
