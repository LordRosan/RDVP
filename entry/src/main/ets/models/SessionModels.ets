import { AuthSession } from './AuthModels';

export interface CurrentUserSnapshot {
  displayName: string;
  roleName: string;
  username?: string;
  expiresAt?: string;
  online: boolean;
}

export interface SessionState {
  authenticated: boolean;
  session?: AuthSession;
}
