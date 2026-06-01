import { ApiClient } from './ApiClient';
import { ApiResponse } from '../models/ApiModels';
import { AuthenticatedUser, AuthSession, LoginForm, LoginValidationResult, RoleCode } from '../models/AuthModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import { PermissionCode } from '../models/PermissionModels';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';

interface LoginApiResult {
  accessToken: string;
  expiresIn: number;
  user: AuthenticatedUser;
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

    if (!ApiClient.isConfigured()) {
      return AuthService.createLocalSession(form);
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

    if (!ApiClient.isConfigured()) {
      return AuthService.createLocalSession(form);
    }

    const response = await ApiClient.request<LoginApiResult>('/api/v1/auth/login', 'POST', false, JSON.stringify({
      username: form.username.trim(),
      password: form.password
    }));

    if (!response.success) {
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
      user: result.user
    };
  }
}
