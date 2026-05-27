import { describe, it, expect } from '@ohos/hypium';
import { WorkbenchService } from '../../../main/ets/services/WorkbenchService';

export default function abilityTest() {
  describe('rdvpAbilityConfiguration', () => {
    it('loadsWorkbenchConfiguration', 0, () => {
      const actions = WorkbenchService.getActions();

      expect(actions.length).assertEqual(8);
    });
  });
}

