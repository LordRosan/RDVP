import { AuthSession } from './AuthModels';

export interface CurrentUserSnapshot {
  displayName: string;
  roleName: string;
  username?: string;
  expiresAt?: string;
  authenticated: boolean;
  online: boolean;
}

export interface SessionState {
  authenticated: boolean;
  session?: AuthSession;
}
