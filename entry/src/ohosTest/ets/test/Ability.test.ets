import { describe, it, expect } from '@ohos/hypium';
import { AuthService } from '../../../main/ets/services/AuthService';
import { DeviceService } from '../../../main/ets/services/DeviceService';
import { VerificationResult } from '../../../main/ets/models/VerificationModels';
import { DeviceVerificationService } from '../../../main/ets/services/DeviceVerificationService';
import { WorkbenchService } from '../../../main/ets/services/WorkbenchService';

export default function abilityTest() {
  describe('rdvpAbilityConfiguration', () => {
    it('loadsWorkbenchConfiguration', 0, () => {
      const actions = WorkbenchService.getActions();

      expect(actions.length).assertEqual(7);
    });

    it('validatesLoginForm', 0, () => {
      const result = AuthService.validateLoginForm({
        username: 'user001',
        password: 'password'
      });

      expect(result.valid).assertEqual(true);
    });

    it('validatesDeviceCodeQuery', 0, () => {
      const result = DeviceService.validateDeviceCodeQuery({
        deviceCode: 'RDVP-DEVICE-0001'
      });

      expect(result.valid).assertEqual(true);
    });

    it('validatesQrQuery', 0, () => {
      const result = DeviceService.validateQrQuery({
        qrContent: 'RDVP:1:RDVP-DEVICE-0001:nonce:signature'
      });

      expect(result.valid).assertEqual(true);
    });

    it('validatesDeviceVerificationForm', 0, () => {
      const result = DeviceVerificationService.validateVerificationForm({
        deviceCode: 'RDVP-DEVICE-0001',
        result: VerificationResult.Normal,
        description: '设备外观完整，运行状态正常。',
        remark: ''
      });

      expect(result.valid).assertEqual(true);
    });
  });
}
