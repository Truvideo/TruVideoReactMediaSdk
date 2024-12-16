# truvideo-react-media-sdk

none

## Installation

```sh
"dependencies": {
  // replace token with your personal access token
    "truvideo-react-media-sdk": "git+https://<token>@github.com/Truvideo/TruVideoReactMediaSdk.git#release-version-76"
}

// or
npm install truvideo-react-media-sdk
```

## Usage


```js
import { uploadMedia } from 'truvideo-react-media-sdk';

// ...
  // setup listener for upload function
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
    // set tag and metadata
    const [tag, setTag] = React.useState<any>(undefined);
    const [metaData, setMetaData] = React.useState<any>(undefined);
    setTag({
            key: "value",
            color: "red",
            orderNumber: "123"
        });
    setMetaData({
            key: "value",
            key1: 1,
            key2: [4, 5, 6]
        });


   // call upload function
   uploadMedia(filePath, tag, metaData)
                    .then((res) => {
                        console.log('Upload successful:', res);
                    })
                    .catch((err) => {
                        console.log('Upload error:', err);
                    })
     // remove listner
     return () => {
      onUploadProgress.remove();
      onUploadError.remove();
      onUploadComplete.remove();
    };
```


## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
