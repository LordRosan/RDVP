import { describe, it, expect } from '@ohos/hypium';
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
}

