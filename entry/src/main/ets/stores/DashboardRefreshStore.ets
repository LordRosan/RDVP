const DASHBOARD_REFRESH_REVISION_STORAGE_KEY = 'rdvp_dashboard_refresh_revision';

export class DashboardRefreshStore {
  static readonly StorageKey: string = DASHBOARD_REFRESH_REVISION_STORAGE_KEY;
  private static initialized: boolean = false;

  static ensureInitialized(): void {
    if (DashboardRefreshStore.initialized) {
      return;
    }

    DashboardRefreshStore.initialized = true;
    try {
      PersistentStorage.persistProp<number>(DASHBOARD_REFRESH_REVISION_STORAGE_KEY, 0);
    } catch (err) {
    }
  }

  static notifyChanged(): void {
    DashboardRefreshStore.ensureInitialized();
    try {
      const current = AppStorage.get<number>(DASHBOARD_REFRESH_REVISION_STORAGE_KEY);
      AppStorage.setOrCreate<number>(DASHBOARD_REFRESH_REVISION_STORAGE_KEY, current === undefined ? 1 : current + 1);
    } catch (err) {
    }
  }

  static shouldRefreshAfterRequest(path: string, method: string): boolean {
    const normalizedPath = DashboardRefreshStore.normalizePath(path);
    const normalizedMethod = method.toUpperCase();
    if (!normalizedPath.startsWith('/api/v1/')) {
      return false;
    }

    if (normalizedPath.startsWith('/api/v1/dashboard') ||
      normalizedPath.startsWith('/api/v1/auth') ||
      normalizedPath.startsWith('/api/v1/audit-logs') ||
      normalizedPath.startsWith('/api/v1/device-codes/')) {
      return false;
    }

    if (normalizedPath === '/api/v1/device-qrcodes/verify') {
      return true;
    }

    if (normalizedPath.startsWith('/api/v1/devices/')) {
      return true;
    }

    if (normalizedPath.startsWith('/api/v1/device-archive-requests')) {
      return true;
    }

    if (normalizedMethod !== 'GET' &&
      (normalizedPath.startsWith('/api/v1/fault-reports') ||
        normalizedPath.startsWith('/api/v1/repair-tasks') ||
        normalizedPath.startsWith('/api/v1/reinspections'))) {
      return true;
    }

    return false;
  }

  private static normalizePath(path: string): string {
    const queryIndex = path.indexOf('?');
    const pathOnly = queryIndex < 0 ? path : path.substring(0, queryIndex);
    return pathOnly.startsWith('/') ? pathOnly : `/${pathOnly}`;
  }
}
