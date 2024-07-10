import { useState, useEffect } from 'react';
import { StyleSheet, View, Text } from 'react-native';
import { NativeEventEmitter, NativeModules } from 'react-native';

export default function App() {
  const [result, setResult] = useState<number | undefined>();

  useEffect(() => {
    const eventEmitter = new NativeEventEmitter(
      NativeModules.TruVideoReactMediaSdk
    );
    let eventListener = eventEmitter.addListener(
      'onError' || 'onProgress' || 'onComplete',
      (event) => {
        setResult(event);
        console.log(event);
      }
    );

    return () => {
      eventListener.remove();
    };
  }, []);

  return (
    <View style={styles.container}>
      <Text>Result: {result}</Text>
    </View>
  );
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
