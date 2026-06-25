import { http } from '@kit.NetworkKit';
import { ApiErrorCode, ApiRequestOptions, ApiResponse } from '../../models/common/ApiModels';
import { DashboardRefreshStore } from '../../stores/DashboardRefreshStore';
import { SessionStore } from '../../stores/SessionStore';
import { SecureRandomService } from './SecureRandomService';
import { UiFeedbackService } from './UiFeedbackService';

const DEFAULT_API_BASE_URL = 'http://localhost:8080';
const API_BASE_URL_STORAGE_KEY = 'rdvp_api_base_url';
const API_BASE_URL_CANDIDATES: string[] = [
  'http://localhost:8080',
  'http://127.0.0.1:8080',
  'http://10.0.2.2:8080'
];
const CLIENT_VERSION = 'rdvp-harmony-0.1.0';
const REQUEST_TIMEOUT_MS = 15000;
const HEALTH_CHECK_TIMEOUT_MS = 3000;

interface ApiHttpHeaders {
  'Content-Type': string;
  'Accept': string;
  'X-Client-Version': string;
  'X-Request-Id': string;
  'Authorization'?: string;
}

export class ApiClient {
  private static baseUrl: string = DEFAULT_API_BASE_URL;
  private static initialized: boolean = false;

  static getBaseUrl(): string {
    ApiClient.ensureInitialized();
    return ApiClient.baseUrl;
  }

  static isConfigured(): boolean {
    return ApiClient.getBaseUrl().length > 0;
  }

  static createServiceUnavailableResponse<T>(): ApiResponse<T> {
    return {
      success: false,
      error: {
        code: ApiErrorCode.ServiceUnavailable,
        message: UiFeedbackService.operationUnavailable('后端服务')
      }
    };
  }

  static async ensureBackendConnected(): Promise<boolean> {
    ApiClient.ensureInitialized();

    const candidates = ApiClient.createBaseUrlCandidates();
    for (let i = 0; i < candidates.length; i++) {
      const candidate = candidates[i];
      if (await ApiClient.checkHealth(candidate)) {
        ApiClient.setBaseUrl(candidate);
        return true;
      }
    }

    return false;
  }

  static createRequestOptions(path: string, method: string, requiresAuth: boolean, body?: string): ApiRequestOptions {
    return {
      path,
      method,
      requiresAuth,
      body
    };
  }

  static async request<T>(
    path: string,
    method: string,
    requiresAuth: boolean,
    body?: string,
    clearSessionOnUnauthorized: boolean = true
  ): Promise<ApiResponse<T>> {
    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<T>();
    }

    const request = http.createHttp();
    try {
      const response = await request.request(ApiClient.createUrl(path), {
        method: ApiClient.toRequestMethod(method),
        header: ApiClient.createHeaders(requiresAuth),
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: REQUEST_TIMEOUT_MS,
        connectTimeout: REQUEST_TIMEOUT_MS
      });

      if (response.responseCode === 401 && clearSessionOnUnauthorized) {
        SessionStore.clearSession();
      }

      const parsedResponse = ApiClient.parseResponse<T>(response.responseCode, `${response.result}`);
      if (parsedResponse.success && DashboardRefreshStore.shouldRefreshAfterRequest(path, method)) {
        DashboardRefreshStore.notifyChanged();
      }

      return parsedResponse;
    } catch (err) {
      return {
        success: false,
        error: {
          code: ApiErrorCode.ServiceUnavailable,
          message: UiFeedbackService.operationUnavailable('后端服务')
        },
        timestamp: new Date().toISOString()
      };
    } finally {
      request.destroy();
    }
  }

  static setBaseUrl(baseUrl: string): void {
    ApiClient.ensureInitialized();
    ApiClient.baseUrl = ApiClient.normalizeBaseUrl(baseUrl);
    ApiClient.persistBaseUrl(ApiClient.baseUrl);
  }

  static normalizeBaseUrlInput(baseUrl: string): string {
    return ApiClient.normalizeBaseUrl(baseUrl);
  }

  static validateBaseUrlInput(baseUrl: string): string {
    const normalized = baseUrl.trim();
    if (normalized.length === 0) {
      return '';
    }

    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      return UiFeedbackService.incorrect('后端服务地址');
    }

    return '';
  }

  static validateRequiredBaseUrlInput(baseUrl: string): string {
    const normalized = baseUrl.trim();
    if (normalized.length === 0) {
      return UiFeedbackService.requiredInput('后端服务地址');
    }

    return ApiClient.validateBaseUrlInput(normalized);
  }

  private static ensureInitialized(): void {
    if (ApiClient.initialized) {
      return;
    }

    ApiClient.initialized = true;
    try {
      PersistentStorage.persistProp<string>(API_BASE_URL_STORAGE_KEY, DEFAULT_API_BASE_URL);
      const storedBaseUrl = AppStorage.get<string>(API_BASE_URL_STORAGE_KEY);
      ApiClient.baseUrl = ApiClient.normalizeBaseUrl(storedBaseUrl === undefined ? DEFAULT_API_BASE_URL : storedBaseUrl);
    } catch (err) {
      ApiClient.baseUrl = ApiClient.normalizeBaseUrl(DEFAULT_API_BASE_URL);
    }
  }

  private static persistBaseUrl(baseUrl: string): void {
    try {
      AppStorage.setOrCreate<string>(API_BASE_URL_STORAGE_KEY, baseUrl);
    } catch (err) {
    }
  }

  private static createBaseUrlCandidates(): string[] {
    const candidates: string[] = [];
    ApiClient.addCandidate(candidates, ApiClient.getBaseUrl());
    for (let i = 0; i < API_BASE_URL_CANDIDATES.length; i++) {
      ApiClient.addCandidate(candidates, API_BASE_URL_CANDIDATES[i]);
    }

    return candidates;
  }

  private static addCandidate(candidates: string[], baseUrl: string): void {
    const normalized = ApiClient.normalizeBaseUrl(baseUrl);
    if (normalized.length === 0) {
      return;
    }

    if (candidates.indexOf(normalized) < 0) {
      candidates.push(normalized);
    }
  }

  private static async checkHealth(baseUrl: string): Promise<boolean> {
    const request = http.createHttp();
    try {
      const response = await request.request(`${baseUrl}/healthz`, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: HEALTH_CHECK_TIMEOUT_MS,
        connectTimeout: HEALTH_CHECK_TIMEOUT_MS
      });

      return response.responseCode >= 200 && response.responseCode < 300;
    } catch (err) {
      return false;
    } finally {
      request.destroy();
    }
  }

  private static normalizeBaseUrl(baseUrl: string): string {
    let normalized = baseUrl.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }

  private static createUrl(path: string): string {
    if (path.startsWith('/')) {
      return `${ApiClient.getBaseUrl()}${path}`;
    }

    return `${ApiClient.getBaseUrl()}/${path}`;
  }

  private static createHeaders(requiresAuth: boolean): ApiHttpHeaders {
    const session = SessionStore.getSessionState().session;
    if (requiresAuth && session !== undefined && session.accessToken.length > 0) {
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Client-Version': CLIENT_VERSION,
        'X-Request-Id': ApiClient.createRequestId(),
        'Authorization': `Bearer ${session.accessToken}`
      };
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client-Version': CLIENT_VERSION,
      'X-Request-Id': ApiClient.createRequestId()
    };
  }

  private static createRequestId(): string {
    return `rdvp-${Date.now()}-${SecureRandomService.createNumericSuffix(6)}`;
  }

  private static toRequestMethod(method: string): http.RequestMethod {
    switch (method.toUpperCase()) {
      case 'POST':
        return http.RequestMethod.POST;
      case 'PUT':
        return http.RequestMethod.PUT;
      case 'DELETE':
        return http.RequestMethod.DELETE;
      case 'GET':
      default:
        return http.RequestMethod.GET;
    }
  }

  private static parseResponse<T>(responseCode: number, responseText: string): ApiResponse<T> {
    if (responseText.trim().length > 0) {
      try {
        return JSON.parse(responseText) as ApiResponse<T>;
      } catch (err) {
        return {
          success: false,
          error: {
            code: ApiErrorCode.InternalError,
            message: UiFeedbackService.operationUnavailable('后端服务')
          },
          timestamp: new Date().toISOString()
        };
      }
    }

    if (responseCode >= 200 && responseCode < 300) {
      return {
        success: true,
        timestamp: new Date().toISOString()
      };
    }

    return {
      success: false,
      error: {
        code: ApiClient.mapStatusToErrorCode(responseCode),
        message: ApiClient.mapStatusToMessage(responseCode)
      },
      timestamp: new Date().toISOString()
    };
  }

  private static mapStatusToErrorCode(responseCode: number): ApiErrorCode {
    switch (responseCode) {
      case 400:
        return ApiErrorCode.BadRequest;
      case 401:
        return ApiErrorCode.Unauthorized;
      case 403:
        return ApiErrorCode.Forbidden;
      case 404:
        return ApiErrorCode.NotFound;
      case 409:
        return ApiErrorCode.Conflict;
      case 422:
        return ApiErrorCode.ValidationFailed;
      case 429:
        return ApiErrorCode.RateLimited;
      default:
        return ApiErrorCode.InternalError;
    }
  }

  private static mapStatusToMessage(responseCode: number): string {
    switch (responseCode) {
      case 400:
        return UiFeedbackService.incorrect('请求参数');
      case 401:
        return UiFeedbackService.operationUnavailable('登录');
      case 403:
        return UiFeedbackService.operationUnavailable('操作');
      case 404:
        return UiFeedbackService.operationUnavailable('查询');
      case 409:
        return UiFeedbackService.operationUnavailable('操作');
      case 422:
        return UiFeedbackService.incorrect('提交内容');
      case 429:
        return UiFeedbackService.operationUnavailable('请求');
      default:
        return UiFeedbackService.operationUnavailable('后端服务');
    }
  }
}
