import { AuthService } from './AuthService';
import { DeviceService } from './DeviceService';
import { SecureRandomService } from './SecureRandomService';
import { ApiResponse } from '../models/ApiModels';

const DELETE_LOCK_STORAGE_KEY = 'rdvp_archive_delete_locks';
const QR_EXPORT_LOCK_STORAGE_KEY = 'rdvp_archive_qrcode_export_locks';
const MAX_PASSWORD_FAILURES = 5;
const DELETE_LOCK_DURATION_MS = 6 * 60 * 60 * 1000;

export interface DeviceArchiveDeleteConfirmationForm {
  deviceCode: string;
  password: string;
  captcha: string;
  expectedCaptcha: string;
}

export interface DeviceArchiveDeleteConfirmationResult {
  verified: boolean;
  message: string;
  lockedUntil?: string;
  failedPasswordAttempts?: number;
}

interface DeviceArchiveDeleteLockRecord {
  deviceCode: string;
  failedPasswordAttempts: number;
  lockedUntil: string;
}

export class DeviceArchiveDeleteGuardService {
  static createCaptcha(): string {
    return SecureRandomService.createSixDigitCode();
  }

  static isDeleteLocked(deviceCode: string): boolean {
    const record = DeviceArchiveDeleteGuardService.findRecord(DELETE_LOCK_STORAGE_KEY, deviceCode);
    if (record === undefined) {
      return false;
    }

    if (!DeviceArchiveDeleteGuardService.isLocked(record)) {
      DeviceArchiveDeleteGuardService.clearRecord(DELETE_LOCK_STORAGE_KEY, deviceCode);
      return false;
    }

    return true;
  }

  static isQrExportLocked(deviceCode: string): boolean {
    const record = DeviceArchiveDeleteGuardService.findRecord(QR_EXPORT_LOCK_STORAGE_KEY, deviceCode);
    if (record === undefined) {
      return false;
    }

    if (!DeviceArchiveDeleteGuardService.isLocked(record)) {
      DeviceArchiveDeleteGuardService.clearRecord(QR_EXPORT_LOCK_STORAGE_KEY, deviceCode);
      return false;
    }

    return true;
  }

  static getDeleteLockMessage(deviceCode: string): string {
    const record = DeviceArchiveDeleteGuardService.findRecord(DELETE_LOCK_STORAGE_KEY, deviceCode);
    if (record === undefined || !DeviceArchiveDeleteGuardService.isLocked(record)) {
      return '当前设备可提交删除申请';
    }

    return `删除功能已锁定，${DeviceArchiveDeleteGuardService.formatDateTime(record.lockedUntil)} 后可再次尝试`;
  }

  static getQrExportLockMessage(deviceCode: string): string {
    const record = DeviceArchiveDeleteGuardService.findRecord(QR_EXPORT_LOCK_STORAGE_KEY, deviceCode);
    if (record === undefined || !DeviceArchiveDeleteGuardService.isLocked(record)) {
      return '当前设备可导出二维码';
    }

    return `二维码导出已锁定，${DeviceArchiveDeleteGuardService.formatDateTime(record.lockedUntil)} 后可再次尝试`;
  }

  static async verifyConfirmation(
    form: DeviceArchiveDeleteConfirmationForm
  ): Promise<DeviceArchiveDeleteConfirmationResult> {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(form.deviceCode);
    if (DeviceArchiveDeleteGuardService.isDeleteLocked(normalizedDeviceCode)) {
      return {
        verified: false,
        message: DeviceArchiveDeleteGuardService.getDeleteLockMessage(normalizedDeviceCode),
        lockedUntil: DeviceArchiveDeleteGuardService.getLockedUntil(normalizedDeviceCode)
      };
    }

    if (form.captcha.trim().length === 0) {
      return {
        verified: false,
        message: '请输入验证码'
      };
    }

    if (form.captcha.trim() !== form.expectedCaptcha.trim()) {
      return {
        verified: false,
        message: '验证码错误，请重新输入'
      };
    }

    if (form.password.length === 0) {
      return {
        verified: false,
        message: '请输入当前账号密码'
      };
    }

    const response = await AuthService.verifyCurrentUserPasswordRemoteFirst(form.password);
    if (response.success && response.data === true) {
      DeviceArchiveDeleteGuardService.clearRecord(DELETE_LOCK_STORAGE_KEY, normalizedDeviceCode);
      return {
        verified: true,
        message: ''
      };
    }

    if (DeviceArchiveDeleteGuardService.isPasswordIncorrectResponse(response)) {
      const record = DeviceArchiveDeleteGuardService.registerPasswordFailure(DELETE_LOCK_STORAGE_KEY, normalizedDeviceCode);
      if (DeviceArchiveDeleteGuardService.isLocked(record)) {
        return {
          verified: false,
          message: DeviceArchiveDeleteGuardService.getDeleteLockMessage(normalizedDeviceCode),
          lockedUntil: record.lockedUntil,
          failedPasswordAttempts: record.failedPasswordAttempts
        };
      }

      return {
        verified: false,
        message: `密码错误，还可尝试${MAX_PASSWORD_FAILURES - record.failedPasswordAttempts}次`,
        failedPasswordAttempts: record.failedPasswordAttempts
      };
    }

    return {
      verified: false,
      message: response.error ? response.error.message : '账号密码校验失败'
    };
  }

  static isPasswordIncorrectResponse(response: ApiResponse<boolean>): boolean {
    if (response.success) {
      return response.data !== true;
    }

    if (response.error === undefined) {
      return false;
    }

    const errorCode = `${response.error.code}`;
    return errorCode === 'INVALID_CREDENTIALS' || errorCode === 'LOGIN_FAILED';
  }

  static registerQrExportPasswordFailure(deviceCode: string): DeviceArchiveDeleteConfirmationResult {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(deviceCode);
    const record = DeviceArchiveDeleteGuardService.registerPasswordFailure(QR_EXPORT_LOCK_STORAGE_KEY, normalizedDeviceCode);
    if (DeviceArchiveDeleteGuardService.isLocked(record)) {
      return {
        verified: false,
        message: DeviceArchiveDeleteGuardService.getQrExportLockMessage(normalizedDeviceCode),
        lockedUntil: record.lockedUntil,
        failedPasswordAttempts: record.failedPasswordAttempts
      };
    }

    return {
      verified: false,
      message: `密码错误，还可尝试${MAX_PASSWORD_FAILURES - record.failedPasswordAttempts}次`,
      failedPasswordAttempts: record.failedPasswordAttempts
    };
  }

  static clearQrExportLock(deviceCode: string): void {
    DeviceArchiveDeleteGuardService.clearRecord(QR_EXPORT_LOCK_STORAGE_KEY, deviceCode);
  }

  private static registerPasswordFailure(storageKey: string, deviceCode: string): DeviceArchiveDeleteLockRecord {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(deviceCode);
    const records = DeviceArchiveDeleteGuardService.readRecords(storageKey);
    const existingIndex = records.findIndex((item: DeviceArchiveDeleteLockRecord) => {
      return item.deviceCode === normalizedDeviceCode;
    });
    const failedPasswordAttempts = existingIndex >= 0 ? records[existingIndex].failedPasswordAttempts + 1 : 1;
    const lockedUntil = failedPasswordAttempts >= MAX_PASSWORD_FAILURES ?
      new Date(Date.now() + DELETE_LOCK_DURATION_MS).toISOString() : '';
    const record: DeviceArchiveDeleteLockRecord = {
      deviceCode: normalizedDeviceCode,
      failedPasswordAttempts,
      lockedUntil
    };

    if (existingIndex >= 0) {
      records[existingIndex] = record;
    } else {
      records.push(record);
    }

    DeviceArchiveDeleteGuardService.writeRecords(storageKey, records);
    return record;
  }

  private static clearRecord(storageKey: string, deviceCode: string): void {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(deviceCode);
    const records = DeviceArchiveDeleteGuardService.readRecords(storageKey).filter((item: DeviceArchiveDeleteLockRecord) => {
      return item.deviceCode !== normalizedDeviceCode;
    });
    DeviceArchiveDeleteGuardService.writeRecords(storageKey, records);
  }

  private static findRecord(storageKey: string, deviceCode: string): DeviceArchiveDeleteLockRecord | undefined {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(deviceCode);
    return DeviceArchiveDeleteGuardService.readRecords(storageKey).find((item: DeviceArchiveDeleteLockRecord) => {
      return item.deviceCode === normalizedDeviceCode;
    });
  }

  private static getLockedUntil(deviceCode: string): string | undefined {
    const record = DeviceArchiveDeleteGuardService.findRecord(DELETE_LOCK_STORAGE_KEY, deviceCode);
    if (record === undefined || record.lockedUntil.length === 0) {
      return undefined;
    }

    return record.lockedUntil;
  }

  private static isLocked(record: DeviceArchiveDeleteLockRecord): boolean {
    return record.lockedUntil.length > 0 && Date.parse(record.lockedUntil) > Date.now();
  }

  private static readRecords(storageKey: string): DeviceArchiveDeleteLockRecord[] {
    try {
      PersistentStorage.persistProp<string>(storageKey, '');
      const text = AppStorage.get<string>(storageKey);
      if (text === undefined || text.length === 0) {
        return [];
      }

      const parsed = JSON.parse(text) as DeviceArchiveDeleteLockRecord[];
      return parsed.filter((item: DeviceArchiveDeleteLockRecord) => {
        return item.deviceCode.length > 0;
      });
    } catch (err) {
      return [];
    }
  }

  private static writeRecords(storageKey: string, records: DeviceArchiveDeleteLockRecord[]): void {
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

    return `${date.getFullYear()}-${DeviceArchiveDeleteGuardService.pad2(date.getMonth() + 1)}-${DeviceArchiveDeleteGuardService.pad2(date.getDate())} ${DeviceArchiveDeleteGuardService.pad2(date.getHours())}:${DeviceArchiveDeleteGuardService.pad2(date.getMinutes())}`;
  }

  private static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
