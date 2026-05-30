import { createHash, createHmac } from 'node:crypto';
import {
  AuditLog,
  AuthSession,
  Device,
  DeviceChangeRequest,
  DeviceQrCode,
  DeviceVerificationRecord,
  FaultReport,
  RepairReport,
  RepairTask,
  ReinspectionRecord,
  UserAccount
} from '../domain/models/entities.js';
import {
  ChangeRequestStatus,
  DeviceStatus,
  FaultSeverity,
  FaultStatus,
  FaultType,
  RoleCode
} from '../domain/models/enums.js';

const QR_SIGNING_SECRET = 'rdvp-local-development-secret';

export class InMemoryDatabase {
  readonly users: UserAccount[] = [];
  readonly sessions: AuthSession[] = [];
  readonly devices: Device[] = [];
  readonly deviceChangeRequests: DeviceChangeRequest[] = [];
  readonly deviceQrCodes: DeviceQrCode[] = [];
  readonly deviceVerificationRecords: DeviceVerificationRecord[] = [];
  readonly faultReports: FaultReport[] = [];
  readonly repairTasks: RepairTask[] = [];
  readonly repairReports: RepairReport[] = [];
  readonly reinspectionRecords: ReinspectionRecord[] = [];
  readonly auditLogs: AuditLog[] = [];

  private sequence = 1000;
  private businessDate = '20260529';

  constructor(seed = true) {
    if (seed) {
      this.seedUsers();
      this.seedDevices();
      this.seedDeviceChangeRequests();
      this.seedDeviceQrCodes();
      this.seedFaultReports();
    }
  }

  nextId(prefix: string): string {
    this.sequence += 1;
    return `${prefix}_${this.sequence}`;
  }

  nextBusinessNo(prefix: string): string {
    this.sequence += 1;
    return `${prefix}-${this.businessDate}-${String(this.sequence).padStart(4, '0')}`;
  }

  now(): string {
    return new Date().toISOString();
  }

  hashPassword(password: string): string {
    return createHash('sha256').update(password, 'utf8').digest('hex');
  }

  buildQrSignature(version: number, deviceCode: string, nonce: string): string {
    const normalizedDeviceCode = deviceCode.trim().toUpperCase();
    return createHmac('sha256', QR_SIGNING_SECRET)
      .update(`${version}:${normalizedDeviceCode}:${nonce}`, 'utf8')
      .digest('hex');
  }

  buildQrContentForDeviceCode(deviceCode: string): string {
    const normalizedDeviceCode = deviceCode.trim().toUpperCase();
    const device = this.devices.find((item) => item.deviceCode === normalizedDeviceCode);
    if (device === undefined) {
      throw new Error(`Device not found: ${normalizedDeviceCode}`);
    }

    const qrCode = this.deviceQrCodes.find((item) => item.deviceId === device.id && item.status === 'ACTIVE');
    if (qrCode === undefined) {
      throw new Error(`Active QR code not found: ${normalizedDeviceCode}`);
    }

    return `RDVP:${qrCode.version}:${normalizedDeviceCode}:${qrCode.nonce}:${qrCode.signatureHash}`;
  }

  private seedUsers(): void {
    const passwordHash = this.hashPassword('password');
    this.users.push(
      {
        id: 'user-admin',
        username: 'admin',
        passwordHash,
        displayName: 'System Admin',
        roles: [RoleCode.SystemAdmin],
        permissions: ['*'],
        status: 'ACTIVE'
      },
      {
        id: 'user-verifier',
        username: 'verifier',
        passwordHash,
        displayName: 'Verifier',
        roles: [RoleCode.Verifier],
        permissions: ['DEVICE_READ', 'DEVICE_VERIFY'],
        status: 'ACTIVE'
      },
      {
        id: 'user-deviceadmin',
        username: 'deviceadmin',
        passwordHash,
        displayName: 'Device Admin',
        roles: [RoleCode.DeviceAdmin],
        permissions: ['DEVICE_READ', 'DEVICE_CHANGE_REVIEW'],
        status: 'ACTIVE'
      },
      {
        id: 'user-reporter',
        username: 'reporter',
        passwordHash,
        displayName: 'Fault Reporter',
        roles: [RoleCode.FaultReporter],
        permissions: ['DEVICE_READ', 'DEVICE_CHANGE_REQUEST_CREATE', 'FAULT_REPORT_CREATE'],
        status: 'ACTIVE'
      },
      {
        id: 'user-maintainer',
        username: 'maintainer',
        passwordHash,
        displayName: 'Maintainer',
        roles: [RoleCode.Maintainer],
        permissions: ['DEVICE_READ', 'REPAIR_TASK_ACCEPT', 'REPAIR_REPORT_CREATE'],
        status: 'ACTIVE'
      },
      {
        id: 'user-reinspector',
        username: 'reinspector',
        passwordHash,
        displayName: 'Reinspector',
        roles: [RoleCode.Reinspector],
        permissions: ['DEVICE_READ', 'REINSPECTION_CREATE'],
        status: 'ACTIVE'
      }
    );
  }

  private seedDeviceChangeRequests(): void {
    const createdAt = '2026-05-29T10:10:00.000Z';
    this.deviceChangeRequests.push({
      id: 'DCR-LOCAL-0002',
      deviceId: 'device-local-0002',
      applicantId: 'user-reporter',
      status: ChangeRequestStatus.PendingReview,
      reason: 'Site marker location requires archive correction.',
      changes: {
        'location.address': {
          oldValue: 'Plant 2 Packaging Area',
          newValue: 'Plant 2 Packaging Area Section A'
        }
      },
      previousDeviceStatus: DeviceStatus.Normal,
      createdAt,
      updatedAt: createdAt
    });
  }

  private seedDevices(): void {
    const createdAt = '2026-05-29T00:00:00.000Z';
    this.devices.push(
      {
        id: 'device-local-0001',
        deviceCode: 'RDVP-DEVICE-0001',
        name: 'Cooling Pump A-01',
        model: 'CP-1000',
        manufacturer: 'North Equipment',
        location: {
          address: 'Plant 1 Power Area',
          longitude: 114.1694,
          latitude: 22.3193
        },
        status: DeviceStatus.Normal,
        lastVerificationTime: '2026-05-28T09:30:00.000Z',
        changeState: {
          locked: false
        },
        createdAt,
        updatedAt: createdAt
      },
      {
        id: 'device-local-0002',
        deviceCode: 'RDVP-DEVICE-0002',
        name: 'Conveyor Line B-02',
        model: 'CL-2200',
        manufacturer: 'South Automation',
        location: {
          address: 'Plant 2 Packaging Area',
          longitude: 114.1721,
          latitude: 22.3188
        },
        status: DeviceStatus.Normal,
        lastVerificationTime: '2026-05-27T15:20:00.000Z',
        changeState: {
          locked: true,
          pendingRequestId: 'DCR-LOCAL-0002'
        },
        createdAt,
        updatedAt: createdAt
      },
      {
        id: 'device-local-0003',
        deviceCode: 'RDVP-DEVICE-0003',
        name: 'Energy Cabinet C-03',
        model: 'ES-500',
        manufacturer: 'East Energy',
        location: {
          address: 'Plant 3 Energy Storage Area',
          longitude: 114.1662,
          latitude: 22.321
        },
        status: DeviceStatus.Normal,
        lastVerificationTime: '2026-05-26T11:10:00.000Z',
        changeState: {
          locked: false
        },
        createdAt,
        updatedAt: createdAt
      }
    );
  }

  private seedDeviceQrCodes(): void {
    for (const device of this.devices) {
      const version = 1;
      const nonce = `nonce-${device.deviceCode.toLowerCase()}`;
      this.deviceQrCodes.push({
        id: this.nextId('qrcode'),
        deviceId: device.id,
        version,
        nonce,
        signatureHash: this.buildQrSignature(version, device.deviceCode, nonce),
        status: 'ACTIVE',
        issuedAt: '2026-05-29T00:00:00.000Z',
        expiresAt: '2027-05-29T00:00:00.000Z'
      });
    }
  }

  private seedFaultReports(): void {
    const createdAt = '2026-05-29T01:00:00.000Z';
    this.faultReports.push({
      id: 'fault-local-0001',
      faultReportNo: 'FR-20260529-0001',
      deviceId: 'device-local-0003',
      reporterId: 'user-reporter',
      faultType: FaultType.CommunicationFault,
      severity: FaultSeverity.General,
      description: 'Communication link is unstable.',
      sceneCondition: 'Site staff reduced operating load.',
      status: FaultStatus.PendingAcceptance,
      occurredAt: '2026-05-29T00:40:00.000Z',
      location: {
        longitude: 114.1662,
        latitude: 22.321
      },
      createdAt,
      updatedAt: createdAt
    });
  }
}
