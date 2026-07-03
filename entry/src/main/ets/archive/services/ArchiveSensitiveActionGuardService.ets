import { DeviceService } from './DeviceService';
import { ApiResponse } from '../../shared/models/ApiModels';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';

const DELETE_LOCK_STORAGE_KEY = 'rdvp_archive_delete_locks';
const QR_EXPORT_LOCK_STORAGE_KEY = 'rdvp_archive_qrcode_export_locks';
const MAX_PASSWORD_FAILURES = 5;
const ACTION_LOCK_DURATION_MS = 6 * 60 * 60 * 1000;

export interface ArchivePasswordGuardResult {
  verified: boolean;
  message: string;
  lockedUntil?: string;
  failedPasswordAttempts?: number;
}

interface ArchiveActionLockRecord {
  deviceCode: string;
  failedPasswordAttempts: number;
  lockedUntil: string;
}

export class ArchiveSensitiveActionGuardService {
  static isDeleteLocked(deviceCode: string): boolean {
    const record = ArchiveSensitiveActionGuardService.findRecord(DELETE_LOCK_STORAGE_KEY, deviceCode);
    if (record === undefined) {
      return false;
    }

    if (!ArchiveSensitiveActionGuardService.isLocked(record)) {
      ArchiveSensitiveActionGuardService.clearRecord(DELETE_LOCK_STORAGE_KEY, deviceCode);
      return false;
    }

    return true;
  }

  static isQrExportLocked(deviceCode: string): boolean {
    const record = ArchiveSensitiveActionGuardService.findRecord(QR_EXPORT_LOCK_STORAGE_KEY, deviceCode);
    if (record === undefined) {
      return false;
    }

    if (!ArchiveSensitiveActionGuardService.isLocked(record)) {
      ArchiveSensitiveActionGuardService.clearRecord(QR_EXPORT_LOCK_STORAGE_KEY, deviceCode);
      return false;
    }

    return true;
  }

  static getDeleteLockMessage(deviceCode: string): string {
    const record = ArchiveSensitiveActionGuardService.findRecord(DELETE_LOCK_STORAGE_KEY, deviceCode);
    if (record === undefined || !ArchiveSensitiveActionGuardService.isLocked(record)) {
      return '当前设备可提交删除申请';
    }

    return `删除功能已锁定，${ArchiveSensitiveActionGuardService.formatDateTime(record.lockedUntil)} 后可再次尝试`;
  }

  static getQrExportLockMessage(deviceCode: string): string {
    const record = ArchiveSensitiveActionGuardService.findRecord(QR_EXPORT_LOCK_STORAGE_KEY, deviceCode);
    if (record === undefined || !ArchiveSensitiveActionGuardService.isLocked(record)) {
      return '当前设备可导出二维码';
    }

    return `二维码导出已锁定，${ArchiveSensitiveActionGuardService.formatDateTime(record.lockedUntil)} 后可再次尝试`;
  }

  static isPasswordIncorrectResponse(response: ApiResponse<boolean>): boolean {
    if (response.success) {
      return response.data !== true;
    }

    if (response.error === undefined) {
      return false;
    }

    const errorCode = `${response.error.code}`;
    return errorCode === 'PASSWORD_INCORRECT';
  }

  static registerQrExportPasswordFailure(deviceCode: string): ArchivePasswordGuardResult {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(deviceCode);
    const record = ArchiveSensitiveActionGuardService.registerPasswordFailure(QR_EXPORT_LOCK_STORAGE_KEY, normalizedDeviceCode);
    if (ArchiveSensitiveActionGuardService.isLocked(record)) {
      return {
        verified: false,
        message: ArchiveSensitiveActionGuardService.getQrExportLockMessage(normalizedDeviceCode),
        lockedUntil: record.lockedUntil,
        failedPasswordAttempts: record.failedPasswordAttempts
      };
    }

    return {
      verified: false,
      message: `${UiFeedbackService.incorrect('密码')}，还可尝试${MAX_PASSWORD_FAILURES - record.failedPasswordAttempts}次`,
      failedPasswordAttempts: record.failedPasswordAttempts
    };
  }

  static registerDeletePasswordFailure(deviceCode: string): ArchivePasswordGuardResult {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(deviceCode);
    const record = ArchiveSensitiveActionGuardService.registerPasswordFailure(DELETE_LOCK_STORAGE_KEY, normalizedDeviceCode);
    if (ArchiveSensitiveActionGuardService.isLocked(record)) {
      return {
        verified: false,
        message: ArchiveSensitiveActionGuardService.getDeleteLockMessage(normalizedDeviceCode),
        lockedUntil: record.lockedUntil,
        failedPasswordAttempts: record.failedPasswordAttempts
      };
    }

    return {
      verified: false,
      message: `${UiFeedbackService.incorrect('密码')}，还可尝试${MAX_PASSWORD_FAILURES - record.failedPasswordAttempts}次`,
      failedPasswordAttempts: record.failedPasswordAttempts
    };
  }

  static clearDeleteLock(deviceCode: string): void {
    ArchiveSensitiveActionGuardService.clearRecord(DELETE_LOCK_STORAGE_KEY, deviceCode);
  }

  static clearQrExportLock(deviceCode: string): void {
    ArchiveSensitiveActionGuardService.clearRecord(QR_EXPORT_LOCK_STORAGE_KEY, deviceCode);
  }

  private static registerPasswordFailure(storageKey: string, deviceCode: string): ArchiveActionLockRecord {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(deviceCode);
    const records = ArchiveSensitiveActionGuardService.readRecords(storageKey);
    const existingIndex = records.findIndex((item: ArchiveActionLockRecord) => {
      return item.deviceCode === normalizedDeviceCode;
    });
    const failedPasswordAttempts = existingIndex >= 0 ? records[existingIndex].failedPasswordAttempts + 1 : 1;
    const lockedUntil = failedPasswordAttempts >= MAX_PASSWORD_FAILURES ?
      new Date(Date.now() + ACTION_LOCK_DURATION_MS).toISOString() : '';
    const record: ArchiveActionLockRecord = {
      deviceCode: normalizedDeviceCode,
      failedPasswordAttempts,
      lockedUntil
    };

    if (existingIndex >= 0) {
      records[existingIndex] = record;
    } else {
      records.push(record);
    }

    ArchiveSensitiveActionGuardService.writeRecords(storageKey, records);
    return record;
  }

  private static clearRecord(storageKey: string, deviceCode: string): void {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(deviceCode);
    const records = ArchiveSensitiveActionGuardService.readRecords(storageKey).filter((item: ArchiveActionLockRecord) => {
      return item.deviceCode !== normalizedDeviceCode;
    });
    ArchiveSensitiveActionGuardService.writeRecords(storageKey, records);
  }

  private static findRecord(storageKey: string, deviceCode: string): ArchiveActionLockRecord | undefined {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(deviceCode);
    return ArchiveSensitiveActionGuardService.readRecords(storageKey).find((item: ArchiveActionLockRecord) => {
      return item.deviceCode === normalizedDeviceCode;
    });
  }

  private static isLocked(record: ArchiveActionLockRecord): boolean {
    return record.lockedUntil.length > 0 && Date.parse(record.lockedUntil) > Date.now();
  }

  private static readRecords(storageKey: string): ArchiveActionLockRecord[] {
    try {
      PersistentStorage.persistProp<string>(storageKey, '');
      const text = AppStorage.get<string>(storageKey);
      if (text === undefined || text.length === 0) {
        return [];
      }

      const parsed = JSON.parse(text) as ArchiveActionLockRecord[];
      return parsed.filter((item: ArchiveActionLockRecord) => {
        return item.deviceCode.length > 0;
      });
    } catch (err) {
      return [];
    }
  }

  private static writeRecords(storageKey: string, records: ArchiveActionLockRecord[]): void {
    try {
      AppStorage.setOrCreate<string>(storageKey, JSON.stringify(records));
    } catch (err) {
    }
  }

  private static formatDateTime(value: string): string {
    const date = new Date(Date.parse(value));
    if (date.getTime() !== date.getTime()) {
      return '-';
    }

    return `${date.getFullYear()}-${ArchiveSensitiveActionGuardService.pad2(date.getMonth() + 1)}-${ArchiveSensitiveActionGuardService.pad2(date.getDate())} ${ArchiveSensitiveActionGuardService.pad2(date.getHours())}:${ArchiveSensitiveActionGuardService.pad2(date.getMinutes())}`;
  }

  private static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
