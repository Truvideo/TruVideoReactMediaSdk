import { useEffect } from 'react';
import {
  StyleSheet,
  View,
  NativeEventEmitter,
  NativeModules,
} from 'react-native';

export default function App() {
  useEffect(() => {
    const eventEmitter = new NativeEventEmitter(
      NativeModules.TruVideoReactMediaSdk
    );

    const onUploadProgress = eventEmitter.addListener('onProgress', (event) => {
      console.log('onProgress event:', event);
    });

    const onUploadError = eventEmitter.addListener('onError', (event) => {
      console.log('onError event:', event);
    });

    const onUploadComplete = eventEmitter.addListener('onComplete', (event) => {
      console.log('onComplete event:', event);
    });

    return () => {
      onUploadProgress.remove();
      onUploadError.remove();
      onUploadComplete.remove();
    };
  }, []);

  return <View style={styles.container} />;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
