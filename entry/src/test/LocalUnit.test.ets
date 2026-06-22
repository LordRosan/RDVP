import { describe, expect, it } from '@ohos/hypium';
import { DeviceStatus } from '../main/ets/models/archive/DeviceModels';
import { DeviceArchiveRequestService } from '../main/ets/services/archive/DeviceArchiveRequestService';
import { DeviceArchiveUpdateService } from '../main/ets/services/archive/DeviceArchiveUpdateService';

export default function localUnitTest() {
  describe('archiveMutationValidation', () => {
    it('validatesArchiveUpdateRequiresChangedField', 0, () => {
      const result = DeviceArchiveUpdateService.validateUpdateRequestForm({
        deviceId: 'device-local-0001',
        deviceCode: 'RDVP-DEVICE-0001',
        deviceName: 'A',
        model: 'M',
        manufacturer: 'Factory',
        locationAddress: 'Lab',
        reason: '修正档案',
        initiatedAt: '2026-06-22 10:00',
        baseline: {
          deviceName: 'A',
          model: 'M',
          manufacturer: 'Factory',
          locationAddress: 'Lab'
        }
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请修改档案信息');
    });

    it('validatesArchiveUpdateRequiresTime', 0, () => {
      const result = DeviceArchiveUpdateService.validateUpdateRequestForm({
        deviceId: 'device-local-0001',
        deviceCode: 'RDVP-DEVICE-0001',
        deviceName: 'A2',
        model: 'M',
        manufacturer: 'Factory',
        locationAddress: 'Lab',
        reason: '修正档案',
        initiatedAt: '',
        baseline: {
          deviceName: 'A',
          model: 'M',
          manufacturer: 'Factory',
          locationAddress: 'Lab'
        }
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请选择修改时间');
    });

    it('validatesArchiveDeleteRequiresTime', 0, () => {
      const result = DeviceArchiveRequestService.validateDeleteRequestForm({
        device: {
          id: 'device-local-0001',
          deviceCode: 'RDVP-DEVICE-0001',
          name: 'A',
          model: 'M',
          manufacturer: 'Factory',
          location: {
            address: 'Lab'
          },
          status: DeviceStatus.Normal
        },
        reason: '设备退役',
        initiatedAt: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请选择删除时间');
    });

    it('validatesArchiveCreateRequiresTime', 0, () => {
      const result = DeviceArchiveRequestService.validateCreateRequestForm({
        deviceCode: 'RDVP-DEVICE-0002',
        deviceName: 'B',
        model: 'M',
        manufacturer: 'Factory',
        locationAddress: 'Lab',
        reason: '新增设备',
        initiatedAt: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请选择添加时间');
    });

    it('validatesArchiveCreateRequiresModel', 0, () => {
      const result = DeviceArchiveRequestService.validateCreateRequestForm({
        deviceCode: 'RDVP-DEVICE-0002',
        deviceName: 'B',
        model: '',
        manufacturer: 'Factory',
        locationAddress: 'Lab',
        reason: '新增设备',
        initiatedAt: '2026-06-22 10:00'
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入设备型号');
    });

    it('validatesArchiveCreateRequiresManufacturer', 0, () => {
      const result = DeviceArchiveRequestService.validateCreateRequestForm({
        deviceCode: 'RDVP-DEVICE-0002',
        deviceName: 'B',
        model: 'M',
        manufacturer: '',
        locationAddress: 'Lab',
        reason: '新增设备',
        initiatedAt: '2026-06-22 10:00'
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入生产厂商');
    });

    it('validatesArchiveCreateRequiresLocation', 0, () => {
      const result = DeviceArchiveRequestService.validateCreateRequestForm({
        deviceCode: 'RDVP-DEVICE-0002',
        deviceName: 'B',
        model: 'M',
        manufacturer: 'Factory',
        locationAddress: '',
        reason: '新增设备',
        initiatedAt: '2026-06-22 10:00'
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入设备位置');
    });
  });
}
