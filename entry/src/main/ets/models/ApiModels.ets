export enum ApiErrorCode {
  BadRequest = 'BAD_REQUEST',
  Unauthorized = 'UNAUTHORIZED',
  Forbidden = 'FORBIDDEN',
  NotFound = 'NOT_FOUND',
  Conflict = 'CONFLICT',
  ValidationFailed = 'VALIDATION_FAILED',
  OfflineSyncBatchInvalid = 'OFFLINE_SYNC_BATCH_INVALID',
  OfflineSyncRecordInvalid = 'OFFLINE_SYNC_RECORD_INVALID',
  OfflineRecordDuplicated = 'OFFLINE_RECORD_DUPLICATED',
  OfflineRecordConflict = 'OFFLINE_RECORD_CONFLICT',
  RateLimited = 'RATE_LIMITED',
  InternalError = 'INTERNAL_ERROR',
  ServiceUnavailable = 'SERVICE_UNAVAILABLE'
}

export interface ApiError {
  code: ApiErrorCode | string;
  message: string;
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: ApiError;
  requestId?: string;
  timestamp?: string;
}

export interface PageResponse<T> {
  items: T[];
  page: number;
  pageSize: number;
  total: number;
}

export interface ApiRequestOptions {
  path: string;
  method: string;
  requiresAuth: boolean;
  body?: string;
}
