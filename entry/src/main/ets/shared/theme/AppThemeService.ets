import { Configuration, ConfigurationConstant, common } from '@kit.AbilityKit';
import { AppThemeMode } from './ThemeModels';

const THEME_MODE_STORAGE_KEY = 'rdvp_theme_mode';
const THEME_REVISION_STORAGE_KEY = 'rdvp_theme_revision';
const DEFAULT_THEME_MODE = AppThemeMode.FollowSystem;

export class AppThemeService {
  private static themeMode: AppThemeMode = DEFAULT_THEME_MODE;
  private static effectiveDarkMode: boolean = false;
  private static initialized: boolean = false;

  static getThemeMode(): AppThemeMode {
    AppThemeService.ensureInitialized();
    return AppThemeService.themeMode;
  }

  static isDarkTheme(): boolean {
    AppThemeService.ensureInitialized();
    return AppThemeService.themeMode === AppThemeMode.Dark ||
      (AppThemeService.themeMode === AppThemeMode.FollowSystem && AppThemeService.effectiveDarkMode);
  }

  static isFollowingSystem(): boolean {
    AppThemeService.ensureInitialized();
    return AppThemeService.themeMode === AppThemeMode.FollowSystem;
  }

  static getThemeModeLabel(mode: AppThemeMode = AppThemeService.getThemeMode()): string {
    switch (mode) {
      case AppThemeMode.Light:
        return '浅色模式';
      case AppThemeMode.Dark:
        return '深色模式';
      case AppThemeMode.FollowSystem:
      default:
        return '跟随系统';
    }
  }

  static setThemeMode(
    mode: AppThemeMode,
    applicationContext?: common.ApplicationContext,
    configuration?: Configuration
  ): void {
    AppThemeService.ensureInitialized();
    const normalizedMode = AppThemeService.parseThemeMode(mode);
    AppThemeService.themeMode = normalizedMode;
    AppThemeService.syncEffectiveColorModeForThemeMode(normalizedMode);
    AppThemeService.persistThemeMode(normalizedMode);
    AppThemeService.applyToApplication(applicationContext, configuration);
    AppThemeService.notifyThemeChanged();
  }

  static applyToApplication(applicationContext?: common.ApplicationContext, configuration?: Configuration): void {
    AppThemeService.ensureInitialized();
    if (AppThemeService.themeMode === AppThemeMode.FollowSystem) {
      AppThemeService.updateEffectiveColorMode(configuration);
    } else {
      AppThemeService.syncEffectiveColorModeForThemeMode(AppThemeService.themeMode);
    }

    if (applicationContext === undefined) {
      return;
    }

    try {
      applicationContext.setColorMode(AppThemeService.toColorMode(AppThemeService.themeMode));
    } catch (err) {
    }
  }

  static updateEffectiveColorMode(configuration?: Configuration): void {
    AppThemeService.ensureInitialized();
    if (AppThemeService.themeMode !== AppThemeMode.FollowSystem) {
      const previousEffectiveDarkMode = AppThemeService.effectiveDarkMode;
      AppThemeService.syncEffectiveColorModeForThemeMode(AppThemeService.themeMode);
      if (previousEffectiveDarkMode !== AppThemeService.effectiveDarkMode) {
        AppThemeService.notifyThemeChanged();
      }
      return;
    }

    if (configuration === undefined || configuration.colorMode === undefined) {
      return;
    }

    const nextEffectiveDarkMode = configuration.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    if (AppThemeService.effectiveDarkMode === nextEffectiveDarkMode) {
      return;
    }

    AppThemeService.effectiveDarkMode = nextEffectiveDarkMode;
    AppThemeService.notifyThemeChanged();
  }

  private static ensureInitialized(): void {
    if (AppThemeService.initialized) {
      return;
    }

    AppThemeService.initialized = true;
    try {
      PersistentStorage.persistProp<string>(THEME_MODE_STORAGE_KEY, DEFAULT_THEME_MODE);
      PersistentStorage.persistProp<number>(THEME_REVISION_STORAGE_KEY, 0);
      const storedMode = AppStorage.get<string>(THEME_MODE_STORAGE_KEY);
      AppThemeService.themeMode = AppThemeService.parseThemeMode(storedMode);
    } catch (err) {
      AppThemeService.themeMode = DEFAULT_THEME_MODE;
    }
  }

  private static parseThemeMode(mode: string | undefined): AppThemeMode {
    if (mode === AppThemeMode.Light) {
      return AppThemeMode.Light;
    }

    if (mode === AppThemeMode.Dark) {
      return AppThemeMode.Dark;
    }

    return AppThemeMode.FollowSystem;
  }

  private static persistThemeMode(mode: AppThemeMode): void {
    try {
      AppStorage.setOrCreate<string>(THEME_MODE_STORAGE_KEY, mode);
    } catch (err) {
    }
  }

  private static syncEffectiveColorModeForThemeMode(mode: AppThemeMode): void {
    if (mode === AppThemeMode.Light) {
      AppThemeService.effectiveDarkMode = false;
      return;
    }

    if (mode === AppThemeMode.Dark) {
      AppThemeService.effectiveDarkMode = true;
    }
  }

  private static notifyThemeChanged(): void {
    try {
      const current = AppStorage.get<number>(THEME_REVISION_STORAGE_KEY);
      AppStorage.setOrCreate<number>(THEME_REVISION_STORAGE_KEY, current === undefined ? 1 : current + 1);
    } catch (err) {
    }
  }

  private static toColorMode(mode: AppThemeMode): ConfigurationConstant.ColorMode {
    switch (mode) {
      case AppThemeMode.Light:
        return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      case AppThemeMode.Dark:
        return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      case AppThemeMode.FollowSystem:
      default:
        return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    }
  }
}
