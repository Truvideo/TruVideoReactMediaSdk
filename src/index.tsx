import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'truvideo-react-media-sdk' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const TruVideoReactMediaSdk = NativeModules.TruVideoReactMediaSdk
  ? NativeModules.TruVideoReactMediaSdk
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export function uploadMedia(filePath: String): Promise<String> {
  return TruVideoReactMediaSdk.uploadMedia(filePath);
}
