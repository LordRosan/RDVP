import { ApiClient } from './ApiClient';
import { ApiResponse } from '../models/ApiModels';
import { AuthSession, LoginForm, LoginValidationResult, RoleCode } from '../models/AuthModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';

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

  private static createLocalSession(form: LoginForm): ApiResponse<AuthSession> {
    const username = form.username.trim();
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    const session: AuthSession = {
      accessToken: `local-session-${Date.now()}`,
      expiresAt,
      user: {
        id: `local-user-${username}`,
        username,
        displayName: username,
        roles: [
          RoleCode.Verifier,
          RoleCode.FaultReporter,
          RoleCode.Maintainer,
          RoleCode.Reinspector,
          RoleCode.SupervisorAuditor
        ],
        permissions: [
          'DEVICE_READ',
          'DEVICE_VERIFY',
          'FAULT_REPORT_CREATE',
          'REPAIR_TASK_ACCEPT',
          'REPAIR_REPORT_CREATE',
          'REINSPECTION_CREATE',
          'AUDIT_READ'
        ]
      }
    };

    LocalOperationRecordRepository.append(OperationRecordType.AuthLogin, '本地登录', username, '进入本地调试会话', username);
    return {
      success: true,
      data: session,
      requestId: 'local-auth-session',
      timestamp: new Date().toISOString()
    };
  }
}
