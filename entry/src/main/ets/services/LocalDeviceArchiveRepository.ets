import { DeviceStatus, DeviceSummary } from '../models/DeviceModels';

export class LocalDeviceArchiveRepository {
  private static devices?: DeviceSummary[] = undefined;

  static findByCode(deviceCode: string): DeviceSummary | undefined {
    const normalizedDeviceCode = LocalDeviceArchiveRepository.normalizeDeviceCode(deviceCode);
    const devices = LocalDeviceArchiveRepository.getDevices();

    for (let i = 0; i < devices.length; i += 1) {
      if (devices[i].deviceCode === normalizedDeviceCode) {
        return LocalDeviceArchiveRepository.cloneDevice(devices[i]);
      }
    }

    return undefined;
  }

  static findByQrContent(qrContent: string): DeviceSummary | undefined {
    const deviceCode = LocalDeviceArchiveRepository.parseDeviceCodeFromQrContent(qrContent);
    if (deviceCode.length === 0) {
      return undefined;
    }

    return LocalDeviceArchiveRepository.findByCode(deviceCode);
  }

  static markChangePending(deviceCode: string, requestId: string): void {
    const normalizedDeviceCode = LocalDeviceArchiveRepository.normalizeDeviceCode(deviceCode);
    const devices = LocalDeviceArchiveRepository.getDevices();

    for (let i = 0; i < devices.length; i += 1) {
      if (devices[i].deviceCode === normalizedDeviceCode) {
        devices[i].status = DeviceStatus.ChangePendingReview;
        devices[i].changeState = {
          locked: true,
          pendingRequestId: requestId
        };
        return;
      }
    }
  }

  private static parseDeviceCodeFromQrContent(qrContent: string): string {
    const segments = qrContent.trim().split(':');
    if (segments.length < 3 || segments[0] !== 'RDVP') {
      return '';
    }

    return LocalDeviceArchiveRepository.normalizeDeviceCode(segments[2]);
  }

  private static normalizeDeviceCode(deviceCode: string): string {
    return deviceCode.trim().toUpperCase();
  }

  private static getDevices(): DeviceSummary[] {
    if (LocalDeviceArchiveRepository.devices === undefined) {
      LocalDeviceArchiveRepository.devices = [
        {
          id: 'device-local-0001',
          deviceCode: 'RDVP-DEVICE-0001',
          name: '冷却泵A-01',
          model: 'CP-1000',
          manufacturer: '北方设备',
          location: {
            address: '一号厂房动力区',
            longitude: 114.1694,
            latitude: 22.3193
          },
          status: DeviceStatus.Normal,
          lastVerificationTime: '2026-05-28T09:30:00Z'
        },
        {
          id: 'device-local-0002',
          deviceCode: 'RDVP-DEVICE-0002',
          name: '输送线B-02',
          model: 'CL-2200',
          manufacturer: '南部自动化',
          location: {
            address: '二号厂房包装区',
            longitude: 114.1721,
            latitude: 22.3188
          },
          status: DeviceStatus.ChangePendingReview,
          lastVerificationTime: '2026-05-27T15:20:00Z',
          changeState: {
            locked: true,
            pendingRequestId: 'DCR-LOCAL-0002'
          }
        },
        {
          id: 'device-local-0003',
          deviceCode: 'RDVP-DEVICE-0003',
          name: '储能柜C-03',
          model: 'ES-500',
          manufacturer: '东部能源',
          location: {
            address: '三号厂房储能区',
            longitude: 114.1662,
            latitude: 22.321
          },
          status: DeviceStatus.UnderRepair,
          lastVerificationTime: '2026-05-26T11:10:00Z'
        }
      ];
    }

    return LocalDeviceArchiveRepository.devices;
  }

  private static cloneDevice(device: DeviceSummary): DeviceSummary {
    return {
      id: device.id,
      deviceCode: device.deviceCode,
      name: device.name,
      model: device.model,
      manufacturer: device.manufacturer,
      location: {
        address: device.location.address,
        longitude: device.location.longitude,
        latitude: device.location.latitude
      },
      status: device.status,
      lastVerificationTime: device.lastVerificationTime,
      changeState: device.changeState === undefined ? undefined : {
        locked: device.changeState.locked,
        pendingRequestId: device.changeState.pendingRequestId,
        freezeUntil: device.changeState.freezeUntil
      }
    };
  }
}
