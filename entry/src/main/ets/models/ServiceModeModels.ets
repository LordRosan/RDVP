export enum ServiceMode {
  Online = 'ONLINE',
  Offline = 'OFFLINE'
}

export interface ServiceModeState {
  mode: ServiceMode;
  apiBaseUrl: string;
}

export interface ServiceModeTransitionRequest {
  targetMode: ServiceMode;
  apiBaseUrl: string;
  reason: string;
}

export interface ServiceModeTransitionResult {
  success: boolean;
  changed: boolean;
  requiresRelogin: boolean;
  targetMode: ServiceMode;
  message: string;
}
