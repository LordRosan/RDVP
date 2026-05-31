import { AuditLogService } from '../audit/AuditLogService.js';
import { DeviceApplicationService } from './services/DeviceApplicationService.js';
import { DeviceChangeService } from './services/DeviceChangeService.js';
import { FaultWorkflowService } from './services/FaultWorkflowService.js';
import { RuntimeConfig, loadRuntimeConfig } from '../config/RuntimeConfig.js';
import { AuthService } from '../security/AuthService.js';
import { InMemoryDatabase } from '../infrastructure/InMemoryDatabase.js';

export interface AppContext {
  runtimeConfig: RuntimeConfig;
  startedAt: string;
  database: InMemoryDatabase;
  auditLogService: AuditLogService;
  authService: AuthService;
  deviceApplicationService: DeviceApplicationService;
  deviceChangeService: DeviceChangeService;
  faultWorkflowService: FaultWorkflowService;
}

export function createDefaultAppContext(runtimeConfig: RuntimeConfig = loadRuntimeConfig()): AppContext {
  const startedAt = new Date().toISOString();
  const database = new InMemoryDatabase();
  const auditLogService = new AuditLogService(database);
  const authService = new AuthService(database, auditLogService);
  const deviceApplicationService = new DeviceApplicationService(database, auditLogService);
  const deviceChangeService = new DeviceChangeService(database, auditLogService);
  const faultWorkflowService = new FaultWorkflowService(database, auditLogService);

  return {
    runtimeConfig,
    startedAt,
    database,
    auditLogService,
    authService,
    deviceApplicationService,
    deviceChangeService,
    faultWorkflowService
  };
}
