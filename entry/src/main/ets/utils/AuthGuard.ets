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
}
