import { DashboardRefreshStore } from '../stores/DashboardRefreshStore';

export class MainPageNavigator {
  static backOrReplace(uiContext: UIContext, fallbackUrl: string, notifyDashboard: boolean = false): boolean {
    if (notifyDashboard) {
      DashboardRefreshStore.notifyChanged();
    }

    try {
      const router = uiContext.getRouter();
      if (router.getState().index > 1) {
        router.back();
        return true;
      }

      router.replaceUrl({ url: fallbackUrl });
      return true;
    } catch (err) {
      return false;
    }
  }

  static replaceToMainPage(uiContext: UIContext): boolean {
    try {
      const router = uiContext.getRouter();
      if (router.getState().index > 1) {
        router.back({ url: 'pages/MainPage' });
        return true;
      }

      router.replaceUrl({ url: 'pages/MainPage' });
      return true;
    } catch (err) {
      return false;
    }
  }
}
