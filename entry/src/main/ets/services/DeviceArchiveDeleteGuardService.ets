import { AuthService } from './AuthService';
import { DeviceService } from './DeviceService';

const DELETE_LOCK_STORAGE_KEY = 'rdvp_archive_delete_locks';
const MAX_PASSWORD_FAILURES = 5;
const DELETE_LOCK_DURATION_MS = 12 * 60 * 60 * 1000;

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
    const value = Math.floor(Math.random() * 900000) + 100000;
    return `${value}`;
  }

  static isDeleteLocked(deviceCode: string): boolean {
    const record = DeviceArchiveDeleteGuardService.findRecord(deviceCode);
    if (record === undefined) {
      return false;
    }

    if (!DeviceArchiveDeleteGuardService.isLocked(record)) {
      DeviceArchiveDeleteGuardService.clearRecord(deviceCode);
      return false;
    }

    return true;
  }

  static getDeleteLockMessage(deviceCode: string): string {
    const record = DeviceArchiveDeleteGuardService.findRecord(deviceCode);
    if (record === undefined || !DeviceArchiveDeleteGuardService.isLocked(record)) {
      return '当前设备可提交删除申请';
    }

    return `删除功能已锁定，${DeviceArchiveDeleteGuardService.formatDateTime(record.lockedUntil)} 后可再次尝试`;
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
    if (!response.success || response.data !== true) {
      const record = DeviceArchiveDeleteGuardService.registerPasswordFailure(normalizedDeviceCode);
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

    DeviceArchiveDeleteGuardService.clearRecord(normalizedDeviceCode);
    return {
      verified: true,
      message: ''
    };
  }

  private static registerPasswordFailure(deviceCode: string): DeviceArchiveDeleteLockRecord {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(deviceCode);
    const records = DeviceArchiveDeleteGuardService.readRecords();
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

    DeviceArchiveDeleteGuardService.writeRecords(records);
    return record;
  }

  private static clearRecord(deviceCode: string): void {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(deviceCode);
    const records = DeviceArchiveDeleteGuardService.readRecords().filter((item: DeviceArchiveDeleteLockRecord) => {
      return item.deviceCode !== normalizedDeviceCode;
    });
    DeviceArchiveDeleteGuardService.writeRecords(records);
  }

  private static findRecord(deviceCode: string): DeviceArchiveDeleteLockRecord | undefined {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(deviceCode);
    return DeviceArchiveDeleteGuardService.readRecords().find((item: DeviceArchiveDeleteLockRecord) => {
      return item.deviceCode === normalizedDeviceCode;
    });
  }

  private static getLockedUntil(deviceCode: string): string | undefined {
    const record = DeviceArchiveDeleteGuardService.findRecord(deviceCode);
    if (record === undefined || record.lockedUntil.length === 0) {
      return undefined;
    }

    return record.lockedUntil;
  }

  private static isLocked(record: DeviceArchiveDeleteLockRecord): boolean {
    return record.lockedUntil.length > 0 && Date.parse(record.lockedUntil) > Date.now();
  }

  private static readRecords(): DeviceArchiveDeleteLockRecord[] {
    try {
      PersistentStorage.persistProp<string>(DELETE_LOCK_STORAGE_KEY, '');
      const text = AppStorage.get<string>(DELETE_LOCK_STORAGE_KEY);
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

  private static writeRecords(records: DeviceArchiveDeleteLockRecord[]): void {
    try {
      AppStorage.setOrCreate<string>(DELETE_LOCK_STORAGE_KEY, JSON.stringify(records));
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
