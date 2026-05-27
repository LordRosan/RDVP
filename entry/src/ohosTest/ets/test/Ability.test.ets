import { describe, it, expect } from '@ohos/hypium';
import { AuthService } from '../../../main/ets/services/AuthService';
import { DeviceService } from '../../../main/ets/services/DeviceService';
import { WorkbenchService } from '../../../main/ets/services/WorkbenchService';

export default function abilityTest() {
  describe('rdvpAbilityConfiguration', () => {
    it('loadsWorkbenchConfiguration', 0, () => {
      const actions = WorkbenchService.getActions();

      expect(actions.length).assertEqual(8);
    });

    it('validatesLoginForm', 0, () => {
      const result = AuthService.validateLoginForm({
        username: 'user001',
        password: 'password'
      });

      expect(result.valid).assertEqual(true);
    });

    it('validatesDeviceCodeSearch', 0, () => {
      const result = DeviceService.validateDeviceCodeSearch({
        deviceCode: 'RDVP-DEVICE-0001'
      });

      expect(result.valid).assertEqual(true);
    });
  });
}
