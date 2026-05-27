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

  static getCurrentUser(): CurrentUserSnapshot {
    const session = SessionStore.sessionState.session;

    if (SessionStore.sessionState.authenticated && session?.user) {
      return {
        displayName: session.user.displayName,
        roleName: session.user.roles.join(', '),
        online: true
      };
    }

    return {
      displayName: '未登录用户',
      roleName: '权限未加载',
      online: false
    };
  }
}
