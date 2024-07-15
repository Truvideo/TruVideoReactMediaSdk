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

/**
 * Uploads media file to TruVideoReactMediaSdk.
 *
 * @param {string} filePath - The path of the media file to upload
 * @return {Promise<string>} A promise that resolves with the result of the media upload
 */
export function uploadMedia(filePath: string): Promise<string> {
  return TruVideoReactMediaSdk.uploadMedia(filePath);
}
