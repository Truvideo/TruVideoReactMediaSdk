import { NativeModules, Platform } from 'react-native';
import { DeviceEventEmitter } from 'react-native';

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
export function uploadMedia(
  filePath: string,
  tag: object,
  metaData: object
): Promise<string> {
  return TruVideoReactMediaSdk.uploadMedia(
    filePath,
    JSON.stringify(tag),
    JSON.stringify(metaData)
  );
}

export async function getFileUploadRequestById(
  id: string
): Promise<MediaRequest | null> {
  return TruVideoReactMediaSdk.getFileUploadRequestById(id).then(
    (response: string) => {
      try {
        const parsed: MediaData = JSON.parse(response);
        const mediaRequest = new MediaRequest(parsed);
        return mediaRequest;
      } catch (e) {
        console.error('Failed to parse MediaData JSON:', e);
        return null;
      }
    }
  );
}

export enum UploadRequestStatus {
  UPLOADING = 'UPLOADING',
  IDLE = 'IDLE',
  ERROR = 'ERROR',
  PAUSED = 'PAUSED',
  COMPLETED = 'COMPLETED',
  CANCELED = 'CANCELED',
  SYNCHRONIZING = 'SYNCHRONIZING',
}

//const requestList : MediaRequest[] = [];
export async function getAllFileUploadRequests(
  status?: UploadRequestStatus
): Promise<MediaRequest[]> {
  return TruVideoReactMediaSdk.getAllFileUploadRequests(status || '').then(
    (response: string) => {
      try {
        const parsed: MediaData[] = JSON.parse(response);
        const requestList: MediaRequest[] = [];
        parsed.forEach((data) => {
          const existingRequest = requestList.find(
            (request) => request.id === data.id
          );
          if (!existingRequest) {
            const newRequest = new MediaRequest(data);
            requestList.push(newRequest);
          }
        });
        return requestList;
      } catch (e) {
        console.error('Failed to parse MediaData JSON:', e);
        return [];
      }
    }
  );
}

export enum MediaType {
  IMAGE = 'IMAGE',
  VIDEO = 'VIDEO',
  AUDIO = 'AUDIO',
  PDF = 'PDF',
}
export async function search(
  tags: Map<string, string>,
  page: number,
  pageSize: number,
  type?: MediaType
): Promise<SearchData[] | null> {
  const typeData = type || MediaType.IMAGE;
  const tag = JSON.stringify(tags);
  return TruVideoReactMediaSdk.search(
    tag,
    typeData,
    page.toString(),
    pageSize.toString()
  ).then((response: string) => {
    try {
      const parsed: UploadCompleteEventData[] = JSON.parse(response);
      return parsed;
    } catch (e) {
      console.error('Failed to parse MediaData JSON:', e);
      return null;
    }
  });
}


export class MediaBuilder {
  private _filePath: string;
  private _metaData: Map<string, string> = new Map(); // Default to empty JSON string or similar
  private _tag: Map<string, string> = new Map();
  private mediaDetail: MediaData | undefined;
  private listeners: any[] = []; // To store event listener subscriptions
  private currentUploadId: string | undefined;
  constructor(filePath: string) {
    if (!filePath) {
      throw new Error('filePath is required for MediaBuilder.');
    }
    this._filePath = filePath;
  }

  setTag(key: string, value: string): MediaBuilder {
    this._tag.set(key, value);
    return this;
  }

  getTag(): Map<string, string> {
    return this._tag;
  }

  getMetaData(): Map<string, string> {
    return this._metaData;
  }

  setMetaData(key: string, value: string): MediaBuilder {
    this._metaData.set(key, value);
    return this;
  }

  clearTags(): MediaBuilder {
    this._tag.clear;
    return this;
  }

  deleteTag(key: string): MediaBuilder {
    this._tag.delete(key);
    return this;
  }

  deleteMetaData(key: string): MediaBuilder {
    this._metaData.delete(key);
    return this;
  }

  clearMetaDatas(): MediaBuilder {
    this._metaData.clear;
    return this;
  }

  mapToJsonObject(map: Map<string, string>): { [key: string]: string } {
    const obj: { [key: string]: string } = {};
    map.forEach((value, key) => {
      obj[key] = value;
    });
    return obj;
  }

  async build(): Promise<MediaBuilder> {
    const jsonObjectTag = this.mapToJsonObject(this._tag);
    const tag = JSON.stringify(jsonObjectTag);
    const jsonObjectMetadata = this.mapToJsonObject(this._metaData);
    const metaData = JSON.stringify(jsonObjectMetadata);
    const response = await TruVideoReactMediaSdk.mediaBuilder(
      this._filePath,
      tag,
      metaData
    );
    this.mediaDetail = JSON.parse(response);
    return this;
  }

  cancel(): Promise<string> {
    if (this.mediaDetail === undefined) {
      return Promise.reject(
        new Error('Cannot cancel: mediaDetail is undefined.')
      );
    }
    return TruVideoReactMediaSdk.cancelMedia(this.mediaDetail.id);
  }
  delete(): Promise<string> {
    if (this.mediaDetail === undefined) {
      return Promise.reject(
        new Error('Cannot delete: mediaDetail is undefined.')
      );
    }
    return TruVideoReactMediaSdk.deleteMedia(this.mediaDetail.id);
  }
  pause(): Promise<string> {
    if (this.mediaDetail === undefined) {
      return Promise.reject(
        new Error('Cannot pause: mediaDetail is undefined.')
      );
    }
    return TruVideoReactMediaSdk.pauseMedia(this.mediaDetail.id);
  }
  resume(): Promise<string> {
    if (this.mediaDetail === undefined) {
      return Promise.reject(
        new Error('Cannot resume: mediaDetail is undefined.')
      );
    }
    return TruVideoReactMediaSdk.resumeMedia(this.mediaDetail.id);
  }

  async upload(
    callbacks: UploadCallbacks
  ): Promise<UploadCompleteEventData | null> {
    if (this.mediaDetail === undefined) {
      return Promise.reject(
        new Error('Cannot upload: mediaDetail is undefined.')
      );
    }

    this.removeEventListeners();
    this.currentUploadId = this.mediaDetail.id;

    // ✅ Use DeviceEventEmitter instead of NativeEventEmitter
    this.listeners.push(
      DeviceEventEmitter.addListener('onProgress', (eventJson: string) => {
        const event: UploadProgressEvent = JSON.parse(eventJson);
        if (event.id === this.currentUploadId && callbacks?.onProgress) {
          callbacks.onProgress(event);
        }
      })
    );

    this.listeners.push(
      DeviceEventEmitter.addListener('onComplete', (eventJson: string) => {
        const event: UploadCompleteEventData = JSON.parse(eventJson);
        if (event.id === this.currentUploadId && callbacks?.onComplete) {
          if (event.metaData && typeof event.metaData === 'string') {
            event.metaData = JSON.parse(event.metaData);
          }
          if (event.tags && typeof event.tags === 'string') {
            event.tags = JSON.parse(event.tags);
          }
          callbacks.onComplete(event);
        }
        this.removeEventListeners();
      })
    );

    this.listeners.push(
      DeviceEventEmitter.addListener('onError', (eventJson: string) => {
        const event: UploadErrorEvent = JSON.parse(eventJson);
        if (event.id === this.currentUploadId && callbacks?.onError) {
          callbacks.onError(event);
        }
        this.removeEventListeners();
      })
    );

    return TruVideoReactMediaSdk.uploadMedia(this.mediaDetail.id).then(
      (response: string) => {
        try {
          const parsed: UploadCompleteEventData = JSON.parse(response);
          return parsed;
        } catch (e) {
          console.error('Failed to parse MediaData JSON:', e);
          return null;
        }
      }
    );
  }

  removeEventListeners(): void {
    this.listeners.forEach((listener) => listener.remove());
    this.listeners = [];
    this.currentUploadId = undefined;
  }
}

export class MediaRequest {
  id: string;
  filePath: string;
  fileType: string;
  createdAt: string;
  updatedAt: string;
  tags: string;
  metaData: string;
  durationMilliseconds: number;
  remoteId: string;
  remoteURL: string;
  transcriptionURL: string;
  transcriptionLength: number;
  status: string;
  progress: number;
  private listeners: any[] = []; // To store event listener subscriptions
  constructor(data: MediaData) {
    this.id = data.id;
    this.filePath = data.filePath;
    this.fileType = data.fileType;
    this.createdAt = data.createdAt;
    this.updatedAt = data.updatedAt;
    this.tags = data.tags;
    this.metaData = data.metaData;
    this.durationMilliseconds = data.durationMilliseconds;
    this.remoteId = data.remoteId;
    this.remoteURL = data.remoteURL;
    this.transcriptionURL = data.transcriptionURL;
    this.transcriptionLength = data.transcriptionLength;
    this.status = data.status;
    this.progress = data.progress;
  }
  updateData(data: MediaData): void {
    this.filePath = data.filePath;
    this.fileType = data.fileType;
    this.createdAt = data.createdAt;
    this.updatedAt = data.updatedAt;
    this.tags = data.tags;
    this.metaData = data.metaData;
    this.durationMilliseconds = data.durationMilliseconds;
    this.remoteId = data.remoteId;
    this.remoteURL = data.remoteURL;
    this.transcriptionURL = data.transcriptionURL;
    this.transcriptionLength = data.transcriptionLength;
    this.status = data.status;
    this.progress = data.progress;
  }

  cancel(): Promise<string> {
    if (this.id === undefined) {
      return Promise.reject(
        new Error('Cannot cancel: mediaDetail is undefined.')
      );
    }
    return TruVideoReactMediaSdk.cancelMedia(this.id);
  }
  delete(): Promise<string> {
    if (this.id === undefined) {
      return Promise.reject(
        new Error('Cannot delete: mediaDetail is undefined.')
      );
    }
    return TruVideoReactMediaSdk.deleteMedia(this.id);
  }
  pause(): Promise<string> {
    if (this.id === undefined) {
      return Promise.reject(
        new Error('Cannot pause: mediaDetail is undefined.')
      );
    }
    return TruVideoReactMediaSdk.pauseMedia(this.id);
  }
  resume(): Promise<string> {
    if (this.id === undefined) {
      return Promise.reject(
        new Error('Cannot resume: mediaDetail is undefined.')
      );
    }
    return TruVideoReactMediaSdk.resumeMedia(this.id);
  }

  async upload(
    callbacks: UploadCallbacks
  ): Promise<UploadCompleteEventData | null> {
    if (this.id === undefined) {
      return Promise.reject(
        new Error('Cannot upload: mediaDetail is undefined.')
      );
    }

    this.removeEventListeners();

    // ✅ Use DeviceEventEmitter instead of NativeEventEmitter
    this.listeners.push(
      DeviceEventEmitter.addListener('onProgress', (eventJson: string) => {
        const event: UploadProgressEvent = JSON.parse(eventJson);
        if (event.id === this.id && callbacks?.onProgress) {
          callbacks.onProgress(event);
        }
      })
    );

    this.listeners.push(
      DeviceEventEmitter.addListener('onComplete', (eventJson: string) => {
        const event: UploadCompleteEventData = JSON.parse(eventJson);
        if (event.id === this.id && callbacks?.onComplete) {
          if (event.metaData && typeof event.metaData === 'string') {
            event.metaData = JSON.parse(event.metaData);
          }
          if (event.tags && typeof event.tags === 'string') {
            event.tags = JSON.parse(event.tags);
          }
          callbacks.onComplete(event);
        }
        this.removeEventListeners();
      })
    );

    this.listeners.push(
      DeviceEventEmitter.addListener('onError', (eventJson: string) => {
        const event: UploadErrorEvent = JSON.parse(eventJson);
        if (event.id === this.id && callbacks?.onError) {
          callbacks.onError(event);
        }
        this.removeEventListeners();
      })
    );

    return TruVideoReactMediaSdk.uploadMedia(this.id).then(
      (response: string) => {
        try {
          const parsed: UploadCompleteEventData = JSON.parse(response);
          return parsed;
        } catch (e) {
          console.error('Failed to parse MediaData JSON:', e);
          return null;
        }
      }
    );
  }

  removeEventListeners(): void {
    this.listeners.forEach((listener) => listener.remove());
    this.listeners = [];
  }
}

export interface MediaData {
  id: string;
  filePath: string;
  fileType: string;
  createdAt: string;
  updatedAt: string;
  tags: string;
  metaData: string;
  durationMilliseconds: number;
  remoteId: string;
  remoteURL: string;
  transcriptionURL: string;
  transcriptionLength: number;
  status: string;
  progress: number;
}

export interface UploadProgressEvent {
  id: string;
  progress: string;
}

export interface UploadCompleteEventData {
  id: string;
  createdDate?: string;
  remoteId?: string;
  uploadedFileURL?: string;
  metaData?: string;
  tags?: string;
  transcriptionURL?: string;
  transcriptionLength?: number;
  fileType?: string;
}

export interface SearchData {
  id: string;
  createdDate?: string;
  remoteId?: string;
  uploadedFileURL?: string;
  metaData?: string;
  tags?: string;
  transcriptionURL?: string;
  transcriptionLength?: number;
  fileType?: string;
  thumbnailUrl?: string;
  previewUrl?: string;
}

export interface UploadErrorEvent {
  id: string;
  error: any;
}

// ─────────────────────────────────────────────────────────────────────────────
// Stream Upload (multipart / chunked) - Upload Requests
// ─────────────────────────────────────────────────────────────────────────────

export type StreamUploadRequestPart = {
  index: number;
  createdAt?: string;
  updatedAt?: string;
  startedAt?: string;
  endedAt?: string;
  isCompleted: boolean;
};

export type StreamUploadRequestStatus =
  | 'IDLE'
  | 'PAUSED'
  | 'PROCESSING'
  | 'UPLOAD_PENDING'
  | 'UPLOADED'
  | 'ERROR';

export type StreamUploadRequest = {
  id: string; // Android: Long -> string, iOS: String
  status: StreamUploadRequestStatus;
  type?: string;
  progress?: number;
  thumbnailPath?: string;
  mediaId?: string;
  isStartOperationCompleted?: boolean;
  startOperationStartedAt?: string;
  startOperationEndedAt?: string;
  isCompleteOperationCompleted?: boolean;
  completeOperationStartedAt?: string;
  completeOperationEndedAt?: string;
  parts?: StreamUploadRequestPart[];
  createdAt?: string;
  updatedAt?: string;
  startedAt?: string;
  endedAt?: string;
};

export interface SearchByIdData {
  id: string;
  createdDate?: string;
  remoteId?: string;
  uploadedFileURL?: string;
  metaData?: Record<string, any>;
  tags?: Record<string, any>;
  transcriptionURL?: string;
  transcriptionLength?: number;
  fileType?: string;
  title?: string;
  duration?: string;
}

const mapMediaRequestToStreamUploadRequest = (req: MediaRequest | MediaData): StreamUploadRequest => {
  const requestData = req as MediaData;
  return {
    id: requestData.id,
    status: (requestData.status as StreamUploadRequestStatus) || 'IDLE',
    type: requestData.fileType,
    progress:
      typeof requestData.progress === 'number'
        ? requestData.progress > 1
          ? requestData.progress / 100
          : requestData.progress
        : 0,
    mediaId: requestData.remoteId,
    createdAt: requestData.createdAt,
    updatedAt: requestData.updatedAt,
  };
};

export async function createStreamUploadRequest(filePath: string): Promise<StreamUploadRequest> {
  const builder = new MediaBuilder(filePath);
  await builder.build();
  const detail = (builder as any).mediaDetail as MediaData | undefined;
  if (!detail) {
    throw new Error('Unable to create upload request');
  }
  return mapMediaRequestToStreamUploadRequest(detail);
}

export async function getAllStreamUploadRequests(): Promise<StreamUploadRequest[]> {
  const response = await TruVideoReactMediaSdk.getAllStreamUploadRequests();
  try {
    const parsed = JSON.parse(response);
    return parsed as StreamUploadRequest[];
  } catch (e) {
    console.error("Failed to parse stream upload requests:", e);
    return [];
  }
}

export async function getStreamUploadRequestById(id: string): Promise<StreamUploadRequest | null> {
  const response = await TruVideoReactMediaSdk.getStreamUploadRequestById(id);
  try {
    const parsed = JSON.parse(response);
    if (!parsed || Object.keys(parsed).length === 0) return null;
    return parsed as StreamUploadRequest;
  } catch (e) {
    return null;
  }
}

export async function uploadStreamUploadRequest(params: {
  id: string;
  title?: string;
  tags?: Record<string, string> | Map<string, string>;
  metadata?: Record<string, any> | Map<string, any>;
  includeInReport?: boolean;
  isLibrary?: boolean;
}): Promise<StreamUploadRequest> {
  const {
    id,
    title = "",
    tags = {},
    metadata = {},
    includeInReport = true,
    isLibrary = true,
  } = params;

  const tagsObj = tags instanceof Map
    ? Object.fromEntries(tags)
    : tags;

  const metadataObj = metadata instanceof Map
    ? Object.fromEntries(metadata)
    : metadata;

  await TruVideoReactMediaSdk.uploadStreamUploadRequest(
    String(id),
    title,
    JSON.stringify(tagsObj),
    JSON.stringify(metadataObj),
    includeInReport,
    isLibrary
  );

  const req = await getStreamUploadRequestById(id);
  if (!req) {
    throw new Error('Upload request not found');
  }
  return req;
}

export async function pauseStreamUploadRequest(id: string): Promise<void> {
  await TruVideoReactMediaSdk.pauseStreamUploadRequest(id);
}

export async function resumeStreamUploadRequest(id: string): Promise<void> {
  await TruVideoReactMediaSdk.resumeStreamUploadRequest(id);
}

export async function retryStreamUploadRequest(id: string): Promise<void> {
  await TruVideoReactMediaSdk.retryStreamUploadRequest(id);
}

export async function deleteStreamUploadRequest(id: string): Promise<void> {
  await TruVideoReactMediaSdk.deleteStreamUploadRequest(id);
}


// Define the signature for the callbacks MediaBuilder will expect
export interface UploadCallbacks {
  onProgress?: (event: UploadProgressEvent) => void;
  onComplete?: (event: UploadCompleteEventData) => void;
  onError?: (event: UploadErrorEvent) => void;
}


export async function searchById(id: string): Promise<SearchByIdData | null> {
  if (!id) {
    throw new Error('searchById: id must not be empty');
  }
  const response: string = await TruVideoReactMediaSdk.searchById(id);
  try {
    const parsed = JSON.parse(response);
    if (!parsed || !parsed.id) return null;
    return parsed as SearchByIdData;
  } catch (e) {
    console.error('Failed to parse searchById response:', e);
    return null;
  }
}