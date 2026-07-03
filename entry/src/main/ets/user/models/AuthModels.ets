export enum RoleCode {
  SuperAdmin = 'superadmin',
  ArchiveAdmin = 'archiveadmin',
  ArchiveStaff = 'archivestaff',
  OperationsAdmin = 'operationsadmin',
  OperationsStaff = 'operationsstaff',
  GeneralAdmin = 'admin'
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
