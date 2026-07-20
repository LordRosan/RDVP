export interface ArchiveImageDraft {
  id?: string;
  previewUri: string;
  contentBase64?: string;
}

export interface ArchiveImageSubmissionPayload {
  id?: string;
  contentBase64?: string;
}

export interface ArchiveImageContentPayload {
  id: string;
  width: number;
  height: number;
  dataUri: string;
}
