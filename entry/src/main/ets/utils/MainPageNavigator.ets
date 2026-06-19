import { DashboardRefreshStore } from '../stores/DashboardRefreshStore';

export class MainPageNavigator {
  static replaceToMainPage(uiContext: UIContext): boolean {
    DashboardRefreshStore.notifyChanged();
    try {
      const router = uiContext.getRouter();
      router.clear();
      router.replaceUrl({ url: 'pages/MainPage' });
      return true;
    } catch (err) {
      return false;
    }
  }
}
