import { ApiErrorCode, ApiRequestOptions, ApiResponse } from '../models/ApiModels';

const DEFAULT_API_BASE_URL = '';

export class ApiClient {
  static getBaseUrl(): string {
    return DEFAULT_API_BASE_URL;
  }

  static isConfigured(): boolean {
    return DEFAULT_API_BASE_URL.length > 0;
  }

  static getRuntimeStatusLabel(): string {
    return ApiClient.isConfigured() ? '已配置' : '本地模式';
  }

  static getRuntimeStatusTone(): string {
    return ApiClient.isConfigured() ? '#087F5B' : '#2F6FED';
  }

  static createServiceUnavailableResponse<T>(): ApiResponse<T> {
    return {
      success: false,
      error: {
        code: ApiErrorCode.ServiceUnavailable,
        message: '后端服务未配置，暂不能访问'
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
