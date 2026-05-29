import { AuthSession, RoleCode } from '../models/AuthModels';
import { CurrentUserSnapshot, SessionState } from '../models/SessionModels';

export class SessionStore {
  private static sessionState: SessionState = {
    authenticated: false
  };

  static getSessionState(): SessionState {
    return SessionStore.sessionState;
  }

  static isAuthenticated(): boolean {
    return SessionStore.sessionState.authenticated;
  }

  static setSession(session: AuthSession): void {
    SessionStore.sessionState = {
      authenticated: true,
      session
    };
  }

  static clearSession(): void {
    SessionStore.sessionState = {
      authenticated: false
    };
  }

  static getCurrentUser(): CurrentUserSnapshot {
    const session = SessionStore.sessionState.session;

    if (SessionStore.sessionState.authenticated && session?.user) {
      return {
        displayName: session.user.displayName,
        roleName: SessionStore.formatRoleNames(session.user.roles),
        online: true
      };
    }

    return {
      displayName: '未登录用户',
      roleName: '权限未加载',
      online: false
    };
  }

  private static formatRoleNames(roles: RoleCode[]): string {
    if (roles.length === 0) {
      return '权限未加载';
    }

    return roles.map((role: RoleCode) => {
      return SessionStore.formatRoleName(role);
    }).join('、');
  }

  private static formatRoleName(role: RoleCode): string {
    switch (role) {
      case RoleCode.SystemAdmin:
        return '系统管理员';
      case RoleCode.DeviceAdmin:
        return '设备管理员';
      case RoleCode.Verifier:
        return '核验人员';
      case RoleCode.FaultReporter:
        return '报修人员';
      case RoleCode.Maintainer:
        return '维修人员';
      case RoleCode.Reinspector:
        return '复检人员';
      case RoleCode.SupervisorAuditor:
        return '审计人员';
      case RoleCode.ReadOnly:
        return '只读人员';
      default:
        return '-';
    }
  }
}
