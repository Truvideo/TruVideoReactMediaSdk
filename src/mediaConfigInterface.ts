export interface MediaData {
  id: string;
  filePath: string;
  fileType: string;
  durationMilliseconds: number;
  remoteId: string;
  remoteURL: string;
  transcriptionURL: string;
  transcriptionLength: number;
  status: string;
  progress: number;
  // Add other properties as per your mapOf keys
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
  metaData?: any; // Change to 'any' or a specific type after JSON.parse
  tags?: any;
  transcriptionURL?: string;
  transcriptionLength?: number;
  fileType?: string;
}

export interface UploadErrorEvent {
  id: string;
  error: any;
}

// Define the signature for the callbacks MediaBuilder will expect
export interface UploadCallbacks {
  onProgress?: (event: UploadProgressEvent) => void;
  onComplete?: (event: UploadCompleteEventData) => void;
  onError?: (event: UploadErrorEvent) => void;
}