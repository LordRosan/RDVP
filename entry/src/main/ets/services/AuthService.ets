import { ApiClient } from './ApiClient';
import { ApiResponse } from '../models/ApiModels';
import { AuthenticatedUser, AuthSession, LoginForm, LoginValidationResult, RoleCode } from '../models/AuthModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import { PermissionCode } from '../models/PermissionModels';
import { ServiceMode } from '../models/ServiceModeModels';
import { SessionStore } from '../stores/SessionStore';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';

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

  static login(form: LoginForm): ApiResponse<AuthSession> {
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

    if (ApiClient.isOfflineMode()) {
      return AuthService.createLocalSession(form);
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<AuthSession>();
    }

    return ApiClient.createServiceUnavailableResponse<AuthSession>();
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

    if (ApiClient.isOfflineMode()) {
      return AuthService.createLocalSession(form);
    }

    if (!ApiClient.isConfigured()) {
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

    if (ApiClient.isOfflineMode()) {
      if (password === 'password') {
        return {
          success: true,
          data: true,
          requestId: 'local-password-verification',
          timestamp: new Date().toISOString()
        };
      }

      return {
        success: false,
        error: {
          code: 'LOGIN_FAILED',
          message: '账号密码校验失败'
        },
        requestId: 'local-password-verification',
        timestamp: new Date().toISOString()
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

  private static createLocalSession(form: LoginForm): ApiResponse<AuthSession> {
    const username = form.username.trim();
    const user = AuthService.createLocalUser(username);
    if (form.password !== 'password' || user === undefined) {
      return {
        success: false,
        error: {
          code: 'LOGIN_FAILED',
          message: '账号或密码错误'
        },
        requestId: 'local-auth-session',
        timestamp: new Date().toISOString()
      };
    }

    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    const session: AuthSession = {
      accessToken: `local-session-${Date.now()}`,
      expiresAt,
      serviceMode: ServiceMode.Offline,
      user
    };

    LocalOperationRecordRepository.append(OperationRecordType.AuthLogin, '本地登录', username, '进入本地调试会话', username);
    return {
      success: true,
      data: session,
      requestId: 'local-auth-session',
      timestamp: new Date().toISOString()
    };
  }

  private static createLocalUser(username: string): AuthenticatedUser | undefined {
    if (username === 'admin') {
      return {
        id: 'local-user-admin',
        username,
        displayName: 'admin',
        roles: [RoleCode.SystemAdmin],
        permissions: ['*']
      };
    }

    if (username === 'deviceadmin') {
      return {
        id: 'local-user-deviceadmin',
        username,
        displayName: 'deviceadmin',
        roles: [RoleCode.DeviceAdmin],
        permissions: [
          PermissionCode.ArchiveDeviceRead,
          PermissionCode.ArchiveDeviceCreate,
          PermissionCode.ArchiveDeviceDelete,
          PermissionCode.MgmtArchiveChangeReview
        ]
      };
    }

    if (username === 'fieldoperator') {
      return {
        id: 'local-user-fieldoperator',
        username,
        displayName: 'fieldoperator',
        roles: [RoleCode.FieldOperator],
        permissions: [
          PermissionCode.ArchiveDeviceRead,
          PermissionCode.ArchiveChangeRequestCreate,
          PermissionCode.OpsDeviceVerify,
          PermissionCode.OpsFaultReportCreate
        ]
      };
    }

    if (username === 'maintainer') {
      return {
        id: 'local-user-maintainer',
        username,
        displayName: 'maintainer',
        roles: [RoleCode.Maintainer],
        permissions: [
          PermissionCode.ArchiveDeviceRead,
          PermissionCode.OpsRepairTaskAccept,
          PermissionCode.OpsRepairReportCreate
        ]
      };
    }

    if (username === 'reinspector') {
      return {
        id: 'local-user-reinspector',
        username,
        displayName: 'reinspector',
        roles: [RoleCode.Reinspector],
        permissions: [PermissionCode.ArchiveDeviceRead, PermissionCode.OpsReinspectionCreate]
      };
    }

    if (username === 'auditor') {
      return {
        id: 'local-user-auditor',
        username,
        displayName: 'auditor',
        roles: [RoleCode.SupervisorAuditor],
        permissions: [PermissionCode.ArchiveDeviceRead, PermissionCode.MgmtAuditLogRead]
      };
    }

    if (username === 'readonly') {
      return {
        id: 'local-user-readonly',
        username,
        displayName: 'readonly',
        roles: [RoleCode.ReadOnly],
        permissions: [PermissionCode.ArchiveDeviceRead]
      };
    }

    return undefined;
  }

  private static createSessionFromApiResult(result: LoginApiResult): AuthSession {
    const expiresIn = result.expiresIn > 0 ? result.expiresIn : 0;
    return {
      accessToken: result.accessToken,
      expiresAt: new Date(Date.now() + expiresIn * 1000).toISOString(),
      serviceMode: ServiceMode.Online,
      user: result.user
    };
  }
}
