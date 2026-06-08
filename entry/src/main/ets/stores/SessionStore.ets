import { AuthSession, RoleCode } from '../models/AuthModels';
import { AllPermissionCodes } from '../models/PermissionModels';
import { ServiceMode } from '../models/ServiceModeModels';
import { CurrentUserSnapshot, SessionState } from '../models/SessionModels';
import { SecureSessionStorageService } from '../services/SecureSessionStorageService';
import { WorkbenchRefreshStore } from './WorkbenchRefreshStore';

const SESSION_STORAGE_KEY = 'rdvp_auth_session';

export class SessionStore {
  private static sessionState: SessionState = {
    authenticated: false
  };
  private static initialized: boolean = false;

  static getSessionState(): SessionState {
    SessionStore.ensureInitialized();
    return SessionStore.sessionState;
  }

  static isAuthenticated(): boolean {
    SessionStore.ensureInitialized();
    if (SessionStore.sessionState.authenticated && SessionStore.isSessionExpired(SessionStore.sessionState.session)) {
      SessionStore.clearSession();
      return false;
    }

    return SessionStore.sessionState.authenticated;
  }

  static setSession(session: AuthSession): void {
    SessionStore.sessionState = {
      authenticated: true,
      session
    };
    SessionStore.persistSession(session);
    WorkbenchRefreshStore.notifyChanged();
  }

  static clearSession(): void {
    SessionStore.sessionState = {
      authenticated: false
    };
    SessionStore.persistSession(undefined);
    WorkbenchRefreshStore.notifyChanged();
  }

  static getCurrentUser(): CurrentUserSnapshot {
    SessionStore.ensureInitialized();
    const session = SessionStore.sessionState.session;

    if (SessionStore.isAuthenticated() && session?.user) {
      return {
        displayName: session.user.displayName,
        roleName: SessionStore.formatRoleNames(session.user.roles),
        username: session.user.username,
        expiresAt: session.expiresAt,
        authenticated: true,
        online: session.serviceMode === ServiceMode.Online
      };
    }

    return {
      displayName: '未登录用户',
      roleName: '权限未加载',
      authenticated: false,
      online: false
    };
  }

  static getCurrentOperatorName(): string {
    const currentUser = SessionStore.getCurrentUser();
    if (!currentUser.authenticated) {
      return '未登录用户';
    }

    return currentUser.displayName.length > 0 ? currentUser.displayName : '未命名用户';
  }

  static hasPermission(permission: string): boolean {
    SessionStore.ensureInitialized();
    if (!SessionStore.isAuthenticated()) {
      return false;
    }

    const permissions = SessionStore.sessionState.session?.user?.permissions;
    if (permissions === undefined) {
      return false;
    }

    return permissions.includes('*') || permissions.includes(permission);
  }

  static hasAnyPermission(permissions: string[]): boolean {
    SessionStore.ensureInitialized();
    if (!SessionStore.isAuthenticated()) {
      return false;
    }

    const grantedPermissions = SessionStore.sessionState.session?.user?.permissions;
    if (grantedPermissions === undefined) {
      return false;
    }

    if (grantedPermissions.includes('*')) {
      return true;
    }

    return permissions.some((permission: string) => grantedPermissions.includes(permission));
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
      case RoleCode.FieldOperator:
        return '现场运维人员';
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

  private static ensureInitialized(): void {
    if (SessionStore.initialized) {
      return;
    }

    SessionStore.initialized = true;

    try {
      const secureSessionText = SecureSessionStorageService.loadSessionText();
      const sessionText = secureSessionText === undefined ? SessionStore.loadLegacySessionText() : secureSessionText;
      SessionStore.clearLegacySessionText();
      const session = SessionStore.parseSession(sessionText);
      if (session !== undefined && !SessionStore.isSessionExpired(session)) {
        SessionStore.sessionState = {
          authenticated: true,
          session
        };
        SessionStore.persistSession(session);
        return;
      }

      SessionStore.persistSession(undefined);
    } catch (err) {
      SessionStore.sessionState = {
        authenticated: false
      };
    }
  }

  private static persistSession(session: AuthSession | undefined): void {
    try {
      SecureSessionStorageService.saveSessionText(session === undefined ? '' : JSON.stringify(session));
      SessionStore.clearLegacySessionText();
    } catch (err) {
    }
  }

  private static loadLegacySessionText(): string | undefined {
    try {
      PersistentStorage.persistProp<string>(SESSION_STORAGE_KEY, '');
      return AppStorage.get<string>(SESSION_STORAGE_KEY);
    } catch (err) {
      return undefined;
    }
  }

  private static clearLegacySessionText(): void {
    try {
      PersistentStorage.persistProp<string>(SESSION_STORAGE_KEY, '');
      AppStorage.setOrCreate<string>(SESSION_STORAGE_KEY, '');
    } catch (err) {
    }
  }

  private static parseSession(sessionText: string | undefined): AuthSession | undefined {
    if (sessionText === undefined || sessionText.length === 0) {
      return undefined;
    }

    try {
      const session = JSON.parse(sessionText) as AuthSession;
      if (session.accessToken.length === 0 || session.expiresAt.length === 0) {
        return undefined;
      }

      if (session.serviceMode !== ServiceMode.Online && session.serviceMode !== ServiceMode.Offline) {
        session.serviceMode = ServiceMode.Offline;
      }

      return SessionStore.hasSupportedPermissionSet(session) ? session : undefined;
    } catch (err) {
      return undefined;
    }
  }

  private static hasSupportedPermissionSet(session: AuthSession): boolean {
    const permissions = session.user?.permissions;
    if (permissions === undefined || permissions.length === 0) {
      return false;
    }

    return permissions.every((permission: string) => {
      return permission === '*' || AllPermissionCodes.includes(permission);
    });
  }

  private static isSessionExpired(session: AuthSession | undefined): boolean {
    if (session === undefined) {
      return true;
    }

    return Date.parse(session.expiresAt) <= Date.now();
  }
}
