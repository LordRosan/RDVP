import { ApiClient } from '../common/ApiClient';
import { ApiResponse } from '../../models/common/ApiModels';
import { AuthenticatedUser, AuthSession, LoginForm, LoginValidationResult } from '../../models/identity/AuthModels';
import { SessionStore } from '../../stores/SessionStore';

interface LoginApiResult {
  accessToken: string;
  expiresIn: number;
  user: AuthenticatedUser;
}

interface PasswordVerificationApiResult {
  verified: boolean;
}

export class AuthService {
  static validateLoginForm(form: LoginForm): LoginValidationResult {
    const username = form.username.trim();

    if (username.length === 0) {
      return {
        valid: false,
        message: '请输入账号'
      };
    }

    if (form.password.length === 0) {
      return {
        valid: false,
        message: '请输入密码'
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static async loginRemoteFirst(form: LoginForm): Promise<ApiResponse<AuthSession>> {
    const validation = AuthService.validateLoginForm(form);

    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'LOGIN_FORM_INVALID',
          message: validation.message
        }
      };
    }

    if (!await ApiClient.ensureBackendConnected()) {
      return ApiClient.createServiceUnavailableResponse<AuthSession>();
    }

    const response = await ApiClient.request<LoginApiResult>('/api/v1/auth/login', 'POST', false, JSON.stringify({
      username: form.username.trim(),
      password: form.password,
      clientDeviceId: 'rdvp-harmony-app'
    }));

    if (!response.success) {
      if (response.error !== undefined && `${response.error.code}` === 'UNAUTHORIZED') {
        SessionStore.clearSession();
      }

      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    if (response.data === undefined) {
      return {
        success: false,
        error: {
          code: 'LOGIN_RESPONSE_INVALID',
          message: '登录响应无效'
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: AuthService.createSessionFromApiResult(response.data),
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static async verifyCurrentUserPasswordRemoteFirst(password: string): Promise<ApiResponse<boolean>> {
    if (!SessionStore.isAuthenticated()) {
      return {
        success: false,
        error: {
          code: 'AUTH_SESSION_REQUIRED',
          message: '请先登录'
        }
      };
    }

    if (password.length === 0) {
      return {
        success: false,
        error: {
          code: 'PASSWORD_REQUIRED',
          message: '请输入当前账号密码'
        }
      };
    }

    const currentUser = SessionStore.getCurrentUser();
    if (currentUser.username === undefined || currentUser.username.length === 0) {
      return {
        success: false,
        error: {
          code: 'AUTH_USER_INVALID',
          message: '当前账号信息无效'
        }
      };
    }

    const response = await ApiClient.request<PasswordVerificationApiResult>(
      '/api/v1/auth/password-verification',
      'POST',
      true,
      JSON.stringify({ password }),
      false
    );
    if (!response.success) {
      if (response.error !== undefined && `${response.error.code}` === 'UNAUTHORIZED') {
        SessionStore.clearSession();
      }

      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: response.data !== undefined && response.data.verified,
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  private static createSessionFromApiResult(result: LoginApiResult): AuthSession {
    const expiresIn = result.expiresIn > 0 ? result.expiresIn : 0;
    return {
      accessToken: result.accessToken,
      expiresAt: new Date(Date.now() + expiresIn * 1000).toISOString(),
      user: result.user
    };
  }
}
