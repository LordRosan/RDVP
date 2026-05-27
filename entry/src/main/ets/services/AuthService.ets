import { ApiClient } from './ApiClient';
import { ApiResponse } from '../models/ApiModels';
import { AuthSession, LoginForm, LoginValidationResult } from '../models/AuthModels';

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
      return ApiClient.createServiceUnavailableResponse<AuthSession>();
    }

    return ApiClient.createServiceUnavailableResponse<AuthSession>();
  }
}

