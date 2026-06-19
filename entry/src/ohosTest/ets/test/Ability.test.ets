import { describe, it, expect } from '@ohos/hypium';
import { AuthService } from '../../../main/ets/services/identity/AuthService';
import { DeviceService } from '../../../main/ets/services/archive/DeviceService';
import { FaultSeverity, FaultType } from '../../../main/ets/models/operations/FaultModels';
import { RepairReportResult } from '../../../main/ets/models/operations/RepairTaskModels';
import { VerificationResult } from '../../../main/ets/models/operations/VerificationModels';
import { FaultReportService } from '../../../main/ets/services/operations/FaultReportService';
import { DeviceVerificationService } from '../../../main/ets/services/operations/DeviceVerificationService';
import { RepairTaskService } from '../../../main/ets/services/operations/RepairTaskService';
import { MainPageService } from '../../../main/ets/services/app/MainPageService';

export default function abilityTest() {
  describe('rdvpAbilityConfiguration', () => {
    it('loadsMainPageConfiguration', 0, () => {
      const actions = MainPageService.getActions();

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
        qrContent: 'RDVP:1:RDVP-DEVICE-0001:nonce-rdvp-device-0001:f36d5f8b2a520071a5955968704a6dd4017a01e6457f573527867e47813c2807'
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

    it('validatesTaskAcceptanceQuery', 0, () => {
      const result = RepairTaskService.validateTaskAcceptanceQuery({
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
