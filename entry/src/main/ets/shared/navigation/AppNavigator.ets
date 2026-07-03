import { UiFeedbackService } from '../services/UiFeedbackService';
import { DashboardRefreshStore } from '../stores/DashboardRefreshStore';
import { AppRoutes } from './AppRoutes';

export type NavigationFailureHandler = () => void;
export interface BackOrReplaceOptions {
  notifyDashboard?: boolean;
  onFailure?: NavigationFailureHandler;
}

export class AppNavigator {
  static createNavigationFailureHandler(onFailure?: NavigationFailureHandler): (reason: Error) => void {
    return (): void => {
      AppNavigator.notifyFailure(onFailure);
    };
  }

  static push(uiContext: UIContext, url: string, onFailure?: NavigationFailureHandler): void {
    try {
      void uiContext.getRouter()
        .pushUrl({ url })
        .catch(AppNavigator.createNavigationFailureHandler(onFailure));
    } catch (err) {
      AppNavigator.notifyFailure(onFailure);
    }
  }

  static replace(uiContext: UIContext, url: string, onFailure?: NavigationFailureHandler): void {
    try {
      void uiContext.getRouter()
        .replaceUrl({ url })
        .catch(AppNavigator.createNavigationFailureHandler(onFailure));
    } catch (err) {
      AppNavigator.notifyFailure(onFailure);
    }
  }

  static back(uiContext: UIContext, onFailure?: NavigationFailureHandler, url?: string): boolean {
    try {
      if (url !== undefined) {
        uiContext.getRouter().back({ url });
        return true;
      }

      uiContext.getRouter().back();
      return true;
    } catch (err) {
      AppNavigator.notifyFailure(onFailure);
      return false;
    }
  }

  static backOrReplace(uiContext: UIContext, fallbackUrl: string, options?: BackOrReplaceOptions | boolean): boolean {
    const normalizedOptions = AppNavigator.normalizeBackOrReplaceOptions(options);
    if (normalizedOptions.notifyDashboard === true) {
      DashboardRefreshStore.notifyChanged();
    }

    try {
      const router = uiContext.getRouter();
      if (router.getState().index > 1) {
        router.back();
        return true;
      }

      void router.replaceUrl({ url: fallbackUrl })
        .catch(AppNavigator.createNavigationFailureHandler(normalizedOptions.onFailure));
      return true;
    } catch (err) {
      AppNavigator.notifyFailure(normalizedOptions.onFailure);
      return false;
    }
  }

  static replaceToHomePage(uiContext: UIContext, onFailure?: NavigationFailureHandler): boolean {
    try {
      const router = uiContext.getRouter();
      if (router.getState().index > 1) {
        router.back({ url: AppRoutes.HomePage });
        return true;
      }

      void router.replaceUrl({ url: AppRoutes.HomePage })
        .catch(AppNavigator.createNavigationFailureHandler(onFailure));
      return true;
    } catch (err) {
      AppNavigator.notifyFailure(onFailure);
      return false;
    }
  }

  static showNavigationUnavailableToast(uiContext: UIContext): void {
    try {
      uiContext.getPromptAction().showToast({ message: UiFeedbackService.operationUnavailable('页面跳转') });
    } catch (err) {
    }
  }

  private static notifyFailure(onFailure?: NavigationFailureHandler): void {
    if (onFailure !== undefined) {
      onFailure();
    }
  }

  private static normalizeBackOrReplaceOptions(options?: BackOrReplaceOptions | boolean): BackOrReplaceOptions {
    if (options === true) {
      return {
        notifyDashboard: true
      };
    }

    if (options === false || options === undefined) {
      return {};
    }

    return options;
  }
}
