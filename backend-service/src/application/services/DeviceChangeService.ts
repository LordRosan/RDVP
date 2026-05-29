import { AuditLogService } from '../../audit/AuditLogService.js';
import { conflict, notFound, validationFailed } from '../../domain/errors.js';
import { Device, DeviceChangeValue, UserAccount } from '../../domain/models/entities.js';
import { ChangeRequestStatus, DeviceStatus } from '../../domain/models/enums.js';
import { InMemoryDatabase } from '../../infrastructure/InMemoryDatabase.js';

const CHANGE_FREEZE_HOURS = 12;

export class DeviceChangeService {
  constructor(
    private readonly database: InMemoryDatabase,
    private readonly auditLogService: AuditLogService
  ) {}

  createChangeRequest(input: {
    deviceId: string;
    reason: string;
    changes: Record<string, DeviceChangeValue>;
    actor: UserAccount;
    requestId?: string;
  }) {
    const device = this.findDeviceById(input.deviceId);
    const now = this.database.now();

    if (device.changeState.locked || this.hasPendingRequest(device.id)) {
      throw conflict('DEVICE_CHANGE_LOCKED', 'Device archive has a pending change request.');
    }

    if (device.changeState.freezeUntil !== undefined && Date.parse(device.changeState.freezeUntil) > Date.now()) {
      throw conflict('DEVICE_CHANGE_FROZEN', 'Device archive is in change freeze period.');
    }

    if (input.reason.trim().length === 0) {
      throw validationFailed('VALIDATION_FAILED', 'Change reason is required.');
    }

    if (!this.hasEffectiveChanges(input.changes)) {
      throw validationFailed('VALIDATION_FAILED', 'Change request must contain at least one effective field change.');
    }

    this.validateChanges(input.changes);
    this.assertOldValuesMatch(device, input.changes);

    const changeRequest = {
      id: this.database.nextId('device_change'),
      deviceId: device.id,
      applicantId: input.actor.id,
      status: ChangeRequestStatus.PendingReview,
      reason: input.reason.trim(),
      changes: this.cloneChanges(input.changes),
      previousDeviceStatus: device.status,
      createdAt: now,
      updatedAt: now
    };

    this.database.deviceChangeRequests.unshift(changeRequest);
    device.status = DeviceStatus.ChangePendingReview;
    device.changeState = {
      locked: true,
      pendingRequestId: changeRequest.id
    };
    device.updatedAt = now;

    this.auditLogService.record({
      action: 'DEVICE_CHANGE_REQUEST',
      targetType: 'DEVICE',
      targetId: device.id,
      targetNo: device.deviceCode,
      actor: input.actor,
      description: 'Created device archive change request.',
      requestId: input.requestId
    });

    return {
      id: changeRequest.id,
      status: changeRequest.status,
      createdAt: changeRequest.createdAt
    };
  }

  listChangeRequests(query: { deviceCode?: string; status?: ChangeRequestStatus; applicantId?: string }) {
    return this.database.deviceChangeRequests
      .filter((request) => query.status === undefined || request.status === query.status)
      .filter((request) => query.applicantId === undefined || request.applicantId === query.applicantId)
      .filter((request) => {
        if (query.deviceCode === undefined) {
          return true;
        }
        const device = this.findDeviceById(request.deviceId);
        return device.deviceCode === query.deviceCode.trim().toUpperCase();
      })
      .map((request) => {
        const device = this.findDeviceById(request.deviceId);
        return {
          ...request,
          deviceCode: device.deviceCode,
          deviceName: device.name,
          changes: this.cloneChanges(request.changes)
        };
      });
  }

  reviewChangeRequest(input: {
    requestId: string;
    decision: 'APPROVED' | 'REJECTED';
    reviewComment?: string;
    actor: UserAccount;
    requestIdHeader?: string;
  }) {
    const changeRequest = this.database.deviceChangeRequests.find((item) => item.id === input.requestId);
    if (changeRequest === undefined) {
      throw notFound('CHANGE_REQUEST_NOT_FOUND', 'Device change request not found.');
    }

    if (changeRequest.status !== ChangeRequestStatus.PendingReview) {
      throw conflict('CHANGE_REQUEST_ALREADY_REVIEWED', 'Device change request has already been reviewed.');
    }

    const device = this.findDeviceById(changeRequest.deviceId);
    this.validateChanges(changeRequest.changes);
    const now = this.database.now();
    changeRequest.reviewerId = input.actor.id;
    changeRequest.reviewComment = input.reviewComment?.trim();
    changeRequest.reviewedAt = now;
    changeRequest.updatedAt = now;

    if (input.decision === 'APPROVED') {
      this.applyChanges(device, changeRequest.changes);
      changeRequest.status = ChangeRequestStatus.Approved;
      changeRequest.freezeUntil = new Date(Date.now() + CHANGE_FREEZE_HOURS * 60 * 60 * 1000).toISOString();
      device.changeState = {
        locked: false,
        freezeUntil: changeRequest.freezeUntil
      };
      if (!Object.prototype.hasOwnProperty.call(changeRequest.changes, 'status')) {
        device.status = changeRequest.previousDeviceStatus;
      }
    } else if (input.decision === 'REJECTED') {
      changeRequest.status = ChangeRequestStatus.Rejected;
      device.status = changeRequest.previousDeviceStatus;
      device.changeState = {
        locked: false
      };
    } else {
      throw validationFailed('VALIDATION_FAILED', 'Review decision is invalid.');
    }

    device.updatedAt = now;

    this.auditLogService.record({
      action: 'DEVICE_CHANGE_REVIEW',
      targetType: 'DEVICE_CHANGE_REQUEST',
      targetId: changeRequest.id,
      targetNo: device.deviceCode,
      actor: input.actor,
      description: `Reviewed device archive change request: ${input.decision}.`,
      requestId: input.requestIdHeader
    });

    return {
      id: changeRequest.id,
      status: changeRequest.status,
      reviewedAt: changeRequest.reviewedAt,
      freezeUntil: changeRequest.freezeUntil
    };
  }

  private findDeviceById(deviceId: string): Device {
    const device = this.database.devices.find((item) => item.id === deviceId);
    if (device === undefined) {
      throw notFound('DEVICE_NOT_FOUND', 'Device not found.');
    }

    return device;
  }

  private hasPendingRequest(deviceId: string): boolean {
    return this.database.deviceChangeRequests.some((item) => {
      return item.deviceId === deviceId && item.status === ChangeRequestStatus.PendingReview;
    });
  }

  private hasEffectiveChanges(changes: Record<string, DeviceChangeValue>): boolean {
    return Object.values(changes).some((change) => {
      return JSON.stringify(change.oldValue) !== JSON.stringify(change.newValue);
    });
  }

  private validateChanges(changes: Record<string, DeviceChangeValue>): void {
    for (const [field, change] of Object.entries(changes)) {
      switch (field) {
        case 'name':
        case 'model':
        case 'manufacturer':
        case 'location.address':
          this.requireStringValue(change.newValue, field);
          break;
        case 'location.longitude':
        case 'location.latitude':
          this.requireNumberValue(change.newValue, field);
          break;
        case 'status':
          this.requireDeviceStatus(change.newValue);
          break;
        default:
          throw validationFailed('VALIDATION_FAILED', `Unsupported change field: ${field}.`);
      }
    }
  }

  private assertOldValuesMatch(device: Device, changes: Record<string, DeviceChangeValue>): void {
    for (const [field, change] of Object.entries(changes)) {
      const currentValue = this.readDeviceField(device, field);
      if (JSON.stringify(currentValue) !== JSON.stringify(change.oldValue)) {
        throw validationFailed('VALIDATION_FAILED', `${field} oldValue does not match current archive value.`);
      }
    }
  }

  private readDeviceField(device: Device, field: string): unknown {
    switch (field) {
      case 'name':
        return device.name;
      case 'model':
        return device.model;
      case 'manufacturer':
        return device.manufacturer;
      case 'location.address':
        return device.location.address;
      case 'location.longitude':
        return device.location.longitude;
      case 'location.latitude':
        return device.location.latitude;
      case 'status':
        return device.status;
      default:
        throw validationFailed('VALIDATION_FAILED', `Unsupported change field: ${field}.`);
    }
  }

  private cloneChanges(changes: Record<string, DeviceChangeValue>): Record<string, DeviceChangeValue> {
    return Object.fromEntries(Object.entries(changes).map(([key, value]) => {
      return [key, {
        oldValue: value.oldValue,
        newValue: value.newValue
      }];
    }));
  }

  private applyChanges(device: Device, changes: Record<string, DeviceChangeValue>): void {
    for (const [field, change] of Object.entries(changes)) {
      switch (field) {
        case 'name':
          device.name = this.requireStringValue(change.newValue, field);
          break;
        case 'model':
          device.model = this.requireStringValue(change.newValue, field);
          break;
        case 'manufacturer':
          device.manufacturer = this.requireStringValue(change.newValue, field);
          break;
        case 'location.address':
          device.location.address = this.requireStringValue(change.newValue, field);
          break;
        case 'location.longitude':
          device.location.longitude = this.requireNumberValue(change.newValue, field);
          break;
        case 'location.latitude':
          device.location.latitude = this.requireNumberValue(change.newValue, field);
          break;
        case 'status':
          device.status = this.requireDeviceStatus(change.newValue);
          break;
        default:
          throw validationFailed('VALIDATION_FAILED', `Unsupported change field: ${field}.`);
      }
    }
  }

  private requireStringValue(value: unknown, field: string): string {
    if (typeof value !== 'string' || value.trim().length === 0) {
      throw validationFailed('VALIDATION_FAILED', `${field} must be a non-empty string.`);
    }

    return value.trim();
  }

  private requireNumberValue(value: unknown, field: string): number {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      throw validationFailed('VALIDATION_FAILED', `${field} must be a finite number.`);
    }

    return value;
  }

  private requireDeviceStatus(value: unknown): DeviceStatus {
    if (typeof value !== 'string' || !Object.values(DeviceStatus).includes(value as DeviceStatus)) {
      throw validationFailed('VALIDATION_FAILED', 'Device status is invalid.');
    }

    return value as DeviceStatus;
  }
}
