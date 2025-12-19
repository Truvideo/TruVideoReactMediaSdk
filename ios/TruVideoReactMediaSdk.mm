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

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
