import { ApiErrorCode, ApiRequestOptions, ApiResponse } from '../models/ApiModels';

const DEFAULT_API_BASE_URL = '';

export class ApiClient {
  static getBaseUrl(): string {
    return DEFAULT_API_BASE_URL;
  }

  static isConfigured(): boolean {
    return DEFAULT_API_BASE_URL.length > 0;
  }

  static createServiceUnavailableResponse<T>(): ApiResponse<T> {
    return {
      success: false,
      error: {
        code: ApiErrorCode.ServiceUnavailable,
        message: 'Service unavailable.'
      }
    };
  }

  static createRequestOptions(path: string, method: string, requiresAuth: boolean, body?: string): ApiRequestOptions {
    return {
      path,
      method,
      requiresAuth,
      body
    };
  }
}

