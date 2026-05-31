import { SessionStore } from '../stores/SessionStore';

export class AuthGuard {
  static requireAuthenticated(uiContext: UIContext): boolean {
    if (SessionStore.isAuthenticated()) {
      return true;
    }

    try {
      uiContext.getRouter().replaceUrl({ url: 'pages/Login' });
    } catch (err) {
    }
    return false;
  }

  static requirePermission(uiContext: UIContext, permission: string): boolean {
    return AuthGuard.requireAnyPermission(uiContext, [permission]);
  }

  static requireAnyPermission(uiContext: UIContext, permissions: string[]): boolean {
    if (!AuthGuard.requireAuthenticated(uiContext)) {
      return false;
    }

    if (SessionStore.hasAnyPermission(permissions)) {
      return true;
    }

    try {
      uiContext.getRouter().replaceUrl({ url: 'pages/Workbench' });
    } catch (err) {
    }
    return false;
  }
}
