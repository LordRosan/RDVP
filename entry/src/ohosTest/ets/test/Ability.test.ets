import { describe, it, expect } from '@ohos/hypium';
import { AuthService } from '../../../main/ets/services/AuthService';
import { DeviceService } from '../../../main/ets/services/DeviceService';
import { FaultSeverity, FaultType } from '../../../main/ets/models/FaultModels';
import { RepairReportResult } from '../../../main/ets/models/RepairTaskModels';
import { VerificationResult } from '../../../main/ets/models/VerificationModels';
import { FaultReportService } from '../../../main/ets/services/FaultReportService';
import { DeviceVerificationService } from '../../../main/ets/services/DeviceVerificationService';
import { RepairTaskService } from '../../../main/ets/services/RepairTaskService';
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

    it('validatesFaultReportForm', 0, () => {
      const result = FaultReportService.validateFaultReportForm({
        deviceCode: 'RDVP-DEVICE-0001',
        faultType: FaultType.CommunicationFault,
        severity: FaultSeverity.Severe,
        occurredAt: '2026-05-28 16:30',
        description: '设备运行异常，需维修人员进一步检查。',
        sceneCondition: ''
      });

      expect(result.valid).assertEqual(true);
    });

    it('validatesAvailableRepairTaskQuery', 0, () => {
      const result = RepairTaskService.validateAvailableRepairTaskQuery({
        radiusKm: 10
      }, RepairTaskService.createWorkloadSnapshot(0));

      expect(result.valid).assertEqual(true);
    });

    it('validatesRepairReportForm', 0, () => {
      const result = RepairTaskService.validateRepairReportForm({
        taskId: 'RDVP-REPAIR-0001',
        result: RepairReportResult.Repaired,
        repairedAt: '2026-05-28 18:30',
        processDescription: '已完成维修并复测。',
        partsUsed: ''
      });

      expect(result.valid).assertEqual(true);
    });
  });
}
