import { SessionStore } from '../../user/stores/SessionStore';
import { AppRoutes } from '../navigation/AppRoutes';
import { AppNavigator } from '../navigation/AppNavigator';

export class AuthGuard {
  static requireAuthenticated(uiContext: UIContext): boolean {
    if (SessionStore.isAuthenticated()) {
      return true;
    }

    AppNavigator.replace(uiContext, AppRoutes.LoginPage);
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

    AppNavigator.replace(uiContext, AppRoutes.HomePage);
    return false;
  }

  static requireAllPermissions(uiContext: UIContext, permissions: string[]): boolean {
    if (!AuthGuard.requireAuthenticated(uiContext)) {
      return false;
    }

    if (SessionStore.hasAllPermissions(permissions)) {
      return true;
    }

    AppNavigator.replace(uiContext, AppRoutes.HomePage);
    return false;
  }
}
