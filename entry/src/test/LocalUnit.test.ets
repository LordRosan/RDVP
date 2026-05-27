import { describe, it, expect } from '@ohos/hypium';
import { AuthService } from '../main/ets/services/AuthService';
import { DeviceService } from '../main/ets/services/DeviceService';
import { WorkbenchActionId } from '../main/ets/models/WorkbenchModels';
import { WorkbenchService } from '../main/ets/services/WorkbenchService';

export default function localUnitTest() {
  describe('workbenchConfiguration', () => {
    it('providesCoreActions', 0, () => {
      const actions = WorkbenchService.getActions();

      expect(actions.length).assertEqual(8);
      expect(actions[0].id).assertEqual(WorkbenchActionId.DeviceCodeSearch);
      expect(actions[1].id).assertEqual(WorkbenchActionId.QrScan);
    });

    it('providesOperationalMetrics', 0, () => {
      const metrics = WorkbenchService.getMetrics();

      expect(metrics.length).assertEqual(4);
    });
  });

  describe('authConfiguration', () => {
    it('rejectsEmptyUsername', 0, () => {
      const result = AuthService.validateLoginForm({
        username: '',
        password: 'password'
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入账号');
    });

    it('acceptsCompleteLoginForm', 0, () => {
      const result = AuthService.validateLoginForm({
        username: 'user001',
        password: 'password'
      });

      expect(result.valid).assertEqual(true);
    });
  });

  describe('deviceSearchConfiguration', () => {
    it('rejectsEmptyDeviceCode', 0, () => {
      const result = DeviceService.validateDeviceCodeSearch({
        deviceCode: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入设备编号');
    });

    it('normalizesDeviceCode', 0, () => {
      const deviceCode = DeviceService.normalizeDeviceCode(' rdvp-device-0001 ');

      expect(deviceCode).assertEqual('RDVP-DEVICE-0001');
    });

    it('acceptsValidDeviceCode', 0, () => {
      const result = DeviceService.validateDeviceCodeSearch({
        deviceCode: 'RDVP-DEVICE-0001'
      });

      expect(result.valid).assertEqual(true);
    });
  });
}
