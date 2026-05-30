const WORKBENCH_REFRESH_REVISION_KEY = 'rdvp_workbench_refresh_revision';

export class WorkbenchRefreshStore {
  static notifyChanged(): void {
    try {
      const current = AppStorage.get<number>(WORKBENCH_REFRESH_REVISION_KEY);
      AppStorage.setOrCreate<number>(WORKBENCH_REFRESH_REVISION_KEY, current === undefined ? 1 : current + 1);
    } catch (err) {
    }
  }
}
