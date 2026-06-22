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
import { DeviceArchiveRequestService } from '../../../main/ets/services/archive/DeviceArchiveRequestService';
import { DeviceArchiveUpdateService } from '../../../main/ets/services/archive/DeviceArchiveUpdateService';
import { DeviceStatus } from '../../../main/ets/models/archive/DeviceModels';

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
