#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(TruVideoReactMediaSdk, NSObject)

RCT_EXTERN_METHOD(uploadMedia:(NSString)filePath
                 withTag:(NSString)tag
                 withMetaData:(NSString)metaData
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
