import { InMemoryDatabase } from '../infrastructure/InMemoryDatabase.js';
import { AuditLog, UserAccount } from '../domain/models/entities.js';
import { OperationRecordStatus } from '../domain/models/enums.js';

export interface AuditRecordInput {
  action: string;
  targetType: string;
  targetId?: string;
  targetNo?: string;
  actor?: UserAccount;
  status?: OperationRecordStatus;
  description: string;
  requestId?: string;
}

export class AuditLogService {
  constructor(private readonly database: InMemoryDatabase) {}

  record(input: AuditRecordInput): AuditLog {
    const auditLog: AuditLog = {
      id: this.database.nextId('audit'),
      action: input.action,
      targetType: input.targetType,
      targetId: input.targetId,
      targetNo: input.targetNo,
      actorId: input.actor?.id,
      actorName: input.actor?.displayName,
      status: input.status ?? OperationRecordStatus.Success,
      description: input.description,
      requestId: input.requestId,
      occurredAt: this.database.now()
    };
    this.database.auditLogs.unshift(auditLog);
    return auditLog;
  }

  list(): AuditLog[] {
    return this.database.auditLogs.map((item) => ({ ...item }));
  }
}
