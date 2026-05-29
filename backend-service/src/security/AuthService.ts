import { randomUUID, timingSafeEqual } from 'node:crypto';
import { AuditLogService } from '../audit/AuditLogService.js';
import { badRequest, forbidden, unauthorized } from '../domain/errors.js';
import { AuthSession, UserAccount } from '../domain/models/entities.js';
import { OperationRecordStatus } from '../domain/models/enums.js';
import { InMemoryDatabase } from '../infrastructure/InMemoryDatabase.js';

const SESSION_TTL_SECONDS = 7 * 24 * 60 * 60;

export class AuthService {
  constructor(
    private readonly database: InMemoryDatabase,
    private readonly auditLogService: AuditLogService
  ) {}

  login(username: string, password: string, requestId?: string): {
    accessToken: string;
    expiresIn: number;
    user: Omit<UserAccount, 'passwordHash' | 'status'>;
  } {
    const normalizedUsername = username.trim();
    if (normalizedUsername.length === 0 || password.length === 0) {
      throw badRequest('BAD_REQUEST', 'Username and password are required.');
    }

    const user = this.database.users.find((item) => item.username === normalizedUsername);
    if (user === undefined || user.status !== 'ACTIVE' || !this.verifyPassword(password, user.passwordHash)) {
      this.auditLogService.record({
        action: 'AUTH_LOGIN',
        targetType: 'USER',
        targetNo: normalizedUsername,
        status: OperationRecordStatus.Failed,
        description: 'Login failed.',
        requestId
      });
      throw unauthorized('Invalid username or password.');
    }

    const expiresAt = new Date(Date.now() + SESSION_TTL_SECONDS * 1000).toISOString();
    const session: AuthSession = {
      accessToken: randomUUID(),
      userId: user.id,
      expiresAt
    };
    this.database.sessions.push(session);

    this.auditLogService.record({
      action: 'AUTH_LOGIN',
      targetType: 'USER',
      targetId: user.id,
      targetNo: user.username,
      actor: user,
      description: 'Login succeeded.',
      requestId
    });

    return {
      accessToken: session.accessToken,
      expiresIn: SESSION_TTL_SECONDS,
      user: this.toPublicUser(user)
    };
  }

  authenticate(authorization: string | undefined): UserAccount {
    if (authorization === undefined || !authorization.startsWith('Bearer ')) {
      throw unauthorized();
    }

    const token = authorization.slice('Bearer '.length).trim();
    const session = this.database.sessions.find((item) => item.accessToken === token);
    if (session === undefined || Date.parse(session.expiresAt) <= Date.now()) {
      throw unauthorized('Session is invalid or expired.');
    }

    const user = this.database.users.find((item) => item.id === session.userId);
    if (user === undefined || user.status !== 'ACTIVE') {
      throw unauthorized('User is invalid or disabled.');
    }

    return user;
  }

  requirePermission(user: UserAccount, permission: string): void {
    if (user.permissions.includes('*') || user.permissions.includes(permission)) {
      return;
    }

    throw forbidden(`Permission ${permission} is required.`);
  }

  toPublicUser(user: UserAccount): Omit<UserAccount, 'passwordHash' | 'status'> {
    return {
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      roles: [...user.roles],
      permissions: [...user.permissions]
    };
  }

  private verifyPassword(password: string, passwordHash: string): boolean {
    const incomingHash = this.database.hashPassword(password);
    const incoming = Buffer.from(incomingHash, 'hex');
    const expected = Buffer.from(passwordHash, 'hex');
    return incoming.length === expected.length && timingSafeEqual(incoming, expected);
  }
}
