import { timingSafeEqual } from 'node:crypto';
import { AuditLogService } from '../../audit/AuditLogService.js';
import { badRequest, notFound } from '../../domain/errors.js';
import { Device, GeoPoint, UserAccount } from '../../domain/models/entities.js';
import { OperationRecordStatus } from '../../domain/models/enums.js';
import { InMemoryDatabase } from '../../infrastructure/InMemoryDatabase.js';

export class DeviceApplicationService {
  constructor(
    private readonly database: InMemoryDatabase,
    private readonly auditLogService: AuditLogService
  ) {}

  findByCode(deviceCode: string): Device {
    const normalizedDeviceCode = this.normalizeDeviceCode(deviceCode);
    const device = this.database.devices.find((item) => item.deviceCode === normalizedDeviceCode);
    if (device === undefined) {
      throw notFound('DEVICE_NOT_FOUND', 'Device not found.');
    }

    return this.cloneDevice(device);
  }

  findById(deviceId: string): Device {
    const device = this.database.devices.find((item) => item.id === deviceId);
    if (device === undefined) {
      throw notFound('DEVICE_NOT_FOUND', 'Device not found.');
    }

    return this.cloneDevice(device);
  }

  verifyQrCode(input: {
    qrContent: string;
    scanLocation?: GeoPoint;
    scannedAt?: string;
    actor: UserAccount;
    requestId?: string;
  }): { valid: true; device: Device } {
    const fail = (code: string, message: string): never => {
      this.auditLogService.record({
        action: 'QR_CODE_VERIFY',
        targetType: 'DEVICE_QRCODE',
        actor: input.actor,
        status: OperationRecordStatus.Failed,
        description: message,
        requestId: input.requestId
      });
      throw badRequest(code, message);
    };

    const parsed = this.parseQrContent(input.qrContent);
    if (parsed === undefined) {
      return fail('QR_CODE_INVALID', 'QR code content is invalid.');
    }

    const device = this.database.devices.find((item) => item.deviceCode === parsed.deviceCode);
    if (device === undefined) {
      return fail('DEVICE_NOT_FOUND', 'Device not found.');
    }

    const qrCode = this.database.deviceQrCodes.find((item) => {
      return item.deviceId === device.id && item.version === parsed.version && item.nonce === parsed.nonce;
    });

    if (qrCode === undefined || qrCode.status === 'REVOKED') {
      return fail('QR_CODE_INVALID', 'QR code content is invalid.');
    }

    if (qrCode.status === 'EXPIRED' || (qrCode.expiresAt !== undefined && Date.parse(qrCode.expiresAt) <= Date.now())) {
      return fail('QR_CODE_EXPIRED', 'QR code is expired.');
    }

    const expectedSignature = this.database.buildQrSignature(parsed.version, parsed.deviceCode, parsed.nonce);
    if (!this.constantTimeEqual(parsed.signature, expectedSignature) || parsed.signature !== qrCode.signatureHash) {
      return fail('QR_CODE_SIGNATURE_INVALID', 'QR code signature verification failed.');
    }

    this.auditLogService.record({
      action: 'QR_CODE_VERIFY',
      targetType: 'DEVICE',
      targetId: device.id,
      targetNo: device.deviceCode,
      actor: input.actor,
      description: 'QR code verified.',
      requestId: input.requestId
    });

    return {
      valid: true,
      device: this.cloneDevice(device)
    };
  }

  normalizeDeviceCode(deviceCode: string): string {
    const normalized = deviceCode.trim().toUpperCase();
    if (!/^RDVP-DEVICE-\d{4}$/.test(normalized)) {
      throw badRequest('DEVICE_CODE_INVALID', 'Device code format is invalid.');
    }

    return normalized;
  }

  private parseQrContent(qrContent: string): {
    version: number;
    deviceCode: string;
    nonce: string;
    signature: string;
  } | undefined {
    const segments = qrContent.trim().split(':');
    if (segments.length !== 5) {
      return undefined;
    }

    const prefix = segments[0];
    const versionText = segments[1];
    const deviceCode = segments[2];
    const nonce = segments[3];
    const signature = segments[4];

    if (
      prefix !== 'RDVP' ||
      versionText === undefined ||
      deviceCode === undefined ||
      nonce === undefined ||
      signature === undefined
    ) {
      return undefined;
    }

    const version = Number.parseInt(versionText, 10);
    if (!Number.isInteger(version) || version <= 0 || nonce.length === 0 || signature.length === 0) {
      return undefined;
    }

    const normalizedDeviceCode = deviceCode.trim().toUpperCase();
    if (!/^RDVP-DEVICE-\d{4}$/.test(normalizedDeviceCode)) {
      return undefined;
    }

    return {
      version,
      deviceCode: normalizedDeviceCode,
      nonce,
      signature
    };
  }

  private constantTimeEqual(left: string, right: string): boolean {
    const leftBuffer = Buffer.from(left, 'utf8');
    const rightBuffer = Buffer.from(right, 'utf8');
    return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
  }

  private cloneDevice(device: Device): Device {
    return {
      ...device,
      location: { ...device.location },
      changeState: { ...device.changeState }
    };
  }
}
