const HOME_PAGE_HOME_SCROLL_Y_STORAGE_KEY = 'rdvp_home_page_home_scroll_y';

export class HomeViewportStore {
  private static initialized: boolean = false;

  static ensureInitialized(): void {
    if (HomeViewportStore.initialized) {
      return;
    }

    HomeViewportStore.initialized = true;
    try {
      AppStorage.setOrCreate<number>(HOME_PAGE_HOME_SCROLL_Y_STORAGE_KEY, 0);
    } catch (err) {
    }
  }

  static getHomeScrollY(): number {
    HomeViewportStore.ensureInitialized();
    try {
      const value = AppStorage.get<number>(HOME_PAGE_HOME_SCROLL_Y_STORAGE_KEY);
      if (value === undefined || !Number.isFinite(value) || value < 0) {
        return 0;
      }

      return value;
    } catch (err) {
      return 0;
    }
  }

  static setHomeScrollY(value: number): void {
    HomeViewportStore.ensureInitialized();
    const normalized = Number.isFinite(value) && value > 0 ? value : 0;
    try {
      AppStorage.setOrCreate<number>(HOME_PAGE_HOME_SCROLL_Y_STORAGE_KEY, normalized);
    } catch (err) {
    }
  }
}
