import { describe, it, expect } from '@ohos/hypium';
import { AuthService } from '../../../main/ets/user/services/AuthService';
import { DeviceService } from '../../../main/ets/archive/services/DeviceService';
import { FaultSeverity, FaultType } from '../../../main/ets/operations/models/FaultModels';
import { RepairReportResult } from '../../../main/ets/operations/models/RepairTaskModels';
import { VerificationResult } from '../../../main/ets/operations/models/VerificationAndFaultReportModels';
import { FaultReportService } from '../../../main/ets/operations/services/FaultReportService';
import { VerificationAndFaultReportService } from '../../../main/ets/operations/services/VerificationAndFaultReportService';
import { RepairTaskService } from '../../../main/ets/operations/services/RepairTaskService';
import { HomeService } from '../../../main/ets/home/services/HomeService';
import { ArchiveRequestService } from '../../../main/ets/archive/services/ArchiveRequestService';
import { ArchiveUpdateService } from '../../../main/ets/archive/services/ArchiveUpdateService';
import { DeviceStatus } from '../../../main/ets/archive/models/DeviceModels';

export default function abilityTest() {
  describe('rdvpAbilityConfiguration', () => {
    it('loadsHomePageConfiguration', 0, () => {
      const actions = HomeService.getActions();

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

    it('validatesVerificationForm', 0, () => {
      const result = VerificationAndFaultReportService.validateVerificationForm({
        deviceCode: 'RDVP-DEVICE-0001',
        result: VerificationResult.Normal,
        description: '设备外观完整，运行状态正常。',
        verifiedAt: '2026-05-28 16:30',
        remark: ''
      });

      expect(result.valid).assertEqual(true);
    });

    it('validatesNormalVerificationRequiresDescription', 0, () => {
      const result = VerificationAndFaultReportService.validateVerificationForm({
        deviceCode: 'RDVP-DEVICE-0001',
        result: VerificationResult.Normal,
        description: '',
        verifiedAt: '2026-05-28 16:30',
        remark: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入核验说明');
    });

    it('validatesNormalVerificationRequiresTime', 0, () => {
      const result = VerificationAndFaultReportService.validateVerificationForm({
        deviceCode: 'RDVP-DEVICE-0001',
        result: VerificationResult.Normal,
        description: '设备外观完整，运行状态正常。',
        verifiedAt: '',
        remark: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请选择核验时间');
    });

    it('validatesAbnormalVerificationUsesFaultDescription', 0, () => {
      const result = VerificationAndFaultReportService.validateVerificationAndFaultReportForm({
        verification: {
          deviceCode: 'RDVP-DEVICE-0001',
          result: VerificationResult.Abnormal,
          description: '',
          verifiedAt: '',
          remark: ''
        },
        faultReport: {
          deviceCode: 'RDVP-DEVICE-0001',
          faultType: FaultType.CommunicationFault,
          severity: FaultSeverity.Severe,
          occurredAt: '2026-05-28 16:30',
          description: '设备通信链路异常。',
          sceneCondition: ''
        }
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
      const result = ArchiveUpdateService.validateUpdateRequestForm({
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
      const result = ArchiveUpdateService.validateUpdateRequestForm({
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
      const result = ArchiveRequestService.validateDeleteRequestForm({
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
