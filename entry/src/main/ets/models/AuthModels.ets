export enum RoleCode {
  SystemAdmin = 'SYSTEM_ADMIN',
  DeviceAdmin = 'DEVICE_ADMIN',
  Verifier = 'VERIFIER',
  FaultReporter = 'FAULT_REPORTER',
  Maintainer = 'MAINTAINER',
  Reinspector = 'REINSPECTOR',
  SupervisorAuditor = 'SUPERVISOR_AUDITOR',
  ReadOnly = 'READ_ONLY'
}

export interface LoginForm {
  username: string;
  password: string;
}

export interface LoginValidationResult {
  valid: boolean;
  message: string;
}

export interface AuthenticatedUser {
  id: string;
  username: string;
  displayName: string;
  roles: RoleCode[];
  permissions: string[];
}

export interface AuthSession {
  accessToken: string;
  expiresAt: string;
  user?: AuthenticatedUser;
}

