const path = require('path');

module.exports = {
  project: {
    ios: {
      automaticPodsInstallation: true,
    },
  },
  dependencies: {
    '@trunpm/truvideo-react-media-sdk': {
      root: path.join(__dirname, '..'),
    },
  },
};
