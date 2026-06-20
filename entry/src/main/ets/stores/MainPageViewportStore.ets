const MAIN_PAGE_HOME_SCROLL_Y_STORAGE_KEY = 'rdvp_main_page_home_scroll_y';

export class MainPageViewportStore {
  private static initialized: boolean = false;

  static ensureInitialized(): void {
    if (MainPageViewportStore.initialized) {
      return;
    }

    MainPageViewportStore.initialized = true;
    try {
      AppStorage.setOrCreate<number>(MAIN_PAGE_HOME_SCROLL_Y_STORAGE_KEY, 0);
    } catch (err) {
    }
  }

  static getHomeScrollY(): number {
    MainPageViewportStore.ensureInitialized();
    try {
      const value = AppStorage.get<number>(MAIN_PAGE_HOME_SCROLL_Y_STORAGE_KEY);
      if (value === undefined || !Number.isFinite(value) || value < 0) {
        return 0;
      }

      return value;
    } catch (err) {
      return 0;
    }
  }

  static setHomeScrollY(value: number): void {
    MainPageViewportStore.ensureInitialized();
    const normalized = Number.isFinite(value) && value > 0 ? value : 0;
    try {
      AppStorage.setOrCreate<number>(MAIN_PAGE_HOME_SCROLL_Y_STORAGE_KEY, normalized);
    } catch (err) {
    }
  }
}
