// __tests__/index.test.tsx
import { NativeModules } from 'react-native';
import { uploadMedia } from '../index';

// Mock the NativeModules and TruVideoReactMediaSdk module
jest.mock('react-native', () => ({
  NativeModules: {
    TruVideoReactMediaSdk: {
      uploadMedia: jest.fn(),
    },
  },
  Platform: {
    select: jest.fn().mockImplementation((objs) => objs.default),
  },
}));

describe('uploadMedia', () => {
  const mockFilePath = '/path/to/media/file';
  const mockTag = {
    key: 'tagKey',
    color: 'blue',
    orderNumber: '12345',
  };
  const mockMetaData = {
    key: 'metaKey',
    key1: 1,
    key2: [1, 2, 3],
  };
  const mockResponse = 'mockUploadResponse';

  beforeEach(() => {
    // Clear all instances and calls to constructor and all methods:
    (NativeModules.TruVideoReactMediaSdk.uploadMedia as jest.Mock).mockClear();
  });

  it('calls TruVideoReactMediaSdk.uploadMedia with correct arguments and returns response', async () => {
    // Mock implementation of the uploadMedia method
    (
      NativeModules.TruVideoReactMediaSdk.uploadMedia as jest.Mock
    ).mockResolvedValue(mockResponse);

    const result = await uploadMedia(mockFilePath, mockTag, mockMetaData);

    // Assert that the mock function was called with the correct arguments
    expect(
      NativeModules.TruVideoReactMediaSdk.uploadMedia
    ).toHaveBeenCalledWith(
      mockFilePath,
      JSON.stringify(mockTag),
      JSON.stringify(mockMetaData)
    );
    // Assert that the result is the mocked response
    expect(result).toBe(mockResponse);
  });

  it('handles errors correctly', async () => {
    const mockError = new Error('mock error');
    // Mock implementation of the uploadMedia method to throw an error
    (
      NativeModules.TruVideoReactMediaSdk.uploadMedia as jest.Mock
    ).mockRejectedValue(mockError);

    await expect(
      uploadMedia(mockFilePath, mockTag, mockMetaData)
    ).rejects.toThrow('mock error');

    // Assert that the mock function was called with the correct arguments
    expect(
      NativeModules.TruVideoReactMediaSdk.uploadMedia
    ).toHaveBeenCalledWith(
      mockFilePath,
      JSON.stringify(mockTag),
      JSON.stringify(mockMetaData)
    );
  });
});
