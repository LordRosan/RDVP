export enum ServiceMode {
  Online = 'ONLINE',
  Offline = 'OFFLINE'
}

export interface ServiceModeState {
  mode: ServiceMode;
  apiBaseUrl: string;
}

