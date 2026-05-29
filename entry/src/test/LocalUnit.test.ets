import { describe, it, expect } from '@ohos/hypium';
import { AuthService } from '../main/ets/services/AuthService';
import { DeviceArchiveChangeService } from '../main/ets/services/DeviceArchiveChangeService';
import { DeviceService } from '../main/ets/services/DeviceService';
import { DeviceStatus } from '../main/ets/models/DeviceModels';
import { FaultSeverity, FaultType } from '../main/ets/models/FaultModels';
import { RepairerAvailability, RepairReportResult } from '../main/ets/models/RepairTaskModels';
import { VerificationResult } from '../main/ets/models/VerificationModels';
import { FaultReportService } from '../main/ets/services/FaultReportService';
import { DeviceVerificationService } from '../main/ets/services/DeviceVerificationService';
import { RepairTaskService } from '../main/ets/services/RepairTaskService';
import { WorkbenchActionId } from '../main/ets/models/WorkbenchModels';
import { WorkbenchService } from '../main/ets/services/WorkbenchService';

export default function localUnitTest() {
  describe('workbenchConfiguration', () => {
    it('providesCoreActions', 0, () => {
      const actions = WorkbenchService.getActions();

      expect(actions.length).assertEqual(7);
      expect(actions[0].id).assertEqual(WorkbenchActionId.DeviceQuery);
      expect(actions[0].title).assertEqual('设备档案查询');
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

  describe('deviceQueryConfiguration', () => {
    it('rejectsEmptyDeviceCode', 0, () => {
      const result = DeviceService.validateDeviceCodeQuery({
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
      const result = DeviceService.validateDeviceCodeQuery({
        deviceCode: 'RDVP-DEVICE-0001'
      });

      expect(result.valid).assertEqual(true);
    });

    it('rejectsEmptyQrContent', 0, () => {
      const result = DeviceService.validateQrQuery({
        qrContent: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请先扫描或上传二维码');
    });

    it('acceptsValidQrContent', 0, () => {
      const result = DeviceService.validateQrQuery({
        qrContent: 'RDVP:1:RDVP-DEVICE-0001:nonce:signature'
      });

      expect(result.valid).assertEqual(true);
    });
  });

  describe('deviceChangeConfiguration', () => {
    it('rejectsEmptyChangeDeviceCode', 0, () => {
      const result = DeviceArchiveChangeService.validateChangeRequestForm({
        deviceCode: '',
        deviceName: '新设备名称',
        model: '',
        manufacturer: '',
        locationAddress: '',
        reason: '修正现场铭牌信息。'
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入设备编号');
    });

    it('rejectsEmptyChangedFields', 0, () => {
      const result = DeviceArchiveChangeService.validateChangeRequestForm({
        deviceCode: 'RDVP-DEVICE-0001',
        deviceName: '',
        model: '',
        manufacturer: '',
        locationAddress: '',
        reason: '修正现场铭牌信息。'
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请至少填写一项需要变更的信息');
    });

    it('rejectsEmptyChangeReason', 0, () => {
      const result = DeviceArchiveChangeService.validateChangeRequestForm({
        deviceCode: 'RDVP-DEVICE-0001',
        deviceName: '冷却泵A-01',
        model: '',
        manufacturer: '',
        locationAddress: '',
        reason: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入变更原因');
    });

    it('acceptsCompleteChangeRequest', 0, () => {
      const result = DeviceArchiveChangeService.validateChangeRequestForm({
        deviceCode: ' rdvp-device-0001 ',
        deviceName: '冷却泵A-01',
        model: 'CP-2000',
        manufacturer: '',
        locationAddress: '',
        reason: '现场铭牌与系统档案不一致，需修正。'
      });

      expect(result.valid).assertEqual(true);
      expect(result.normalizedDeviceCode).assertEqual('RDVP-DEVICE-0001');
      expect(result.changeCount).assertEqual(2);
    });

    it('comparesChangeRequestWithBaseline', 0, () => {
      const result = DeviceArchiveChangeService.validateChangeRequestForm({
        deviceCode: 'RDVP-DEVICE-0001',
        deviceName: '冷却泵A-02',
        model: 'CP-1000',
        manufacturer: '北方设备',
        locationAddress: '一号厂房',
        reason: '现场铭牌名称已更新。',
        baseline: {
          deviceName: '冷却泵A-01',
          model: 'CP-1000',
          manufacturer: '北方设备',
          locationAddress: '一号厂房'
        }
      });

      expect(result.valid).assertEqual(true);
      expect(result.changeCount).assertEqual(1);
    });

    it('rejectsUnchangedPrefilledArchive', 0, () => {
      const result = DeviceArchiveChangeService.validateChangeRequestForm({
        deviceCode: 'RDVP-DEVICE-0001',
        deviceName: '冷却泵A-01',
        model: 'CP-1000',
        manufacturer: '北方设备',
        locationAddress: '一号厂房',
        reason: '现场信息确认无误。',
        baseline: {
          deviceName: '冷却泵A-01',
          model: 'CP-1000',
          manufacturer: '北方设备',
          locationAddress: '一号厂房'
        }
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请至少填写一项需要变更的信息');
    });

    it('formatsArchiveStatusAndChangeLock', 0, () => {
      expect(DeviceService.formatDeviceStatus(DeviceStatus.ChangePendingReview)).assertEqual('变更待审核');
      expect(DeviceService.isArchiveChangeLocked({
        id: 'device-1',
        deviceCode: 'RDVP-DEVICE-0001',
        name: '冷却泵A-01',
        model: 'CP-1000',
        manufacturer: '北方设备',
        location: {
          address: '一号厂房'
        },
        status: DeviceStatus.ChangePendingReview,
        changeState: {
          locked: true,
          pendingRequestId: 'RDVP-CHANGE-0001'
        }
      })).assertEqual(true);
    });
  });

  describe('deviceVerificationConfiguration', () => {
    it('rejectsEmptyVerificationDeviceCode', 0, () => {
      const result = DeviceVerificationService.validateVerificationForm({
        deviceCode: '',
        result: VerificationResult.Normal,
        description: '设备现场状态正常',
        remark: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入设备编号');
    });

    it('rejectsEmptyVerificationDescription', 0, () => {
      const result = DeviceVerificationService.validateVerificationForm({
        deviceCode: 'RDVP-DEVICE-0001',
        result: VerificationResult.Normal,
        description: '',
        remark: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入现场描述');
    });

    it('acceptsCompleteVerificationForm', 0, () => {
      const result = DeviceVerificationService.validateVerificationForm({
        deviceCode: 'RDVP-DEVICE-0001',
        result: VerificationResult.Normal,
        description: '设备外观完整，运行状态正常。',
        remark: ''
      });

      expect(result.valid).assertEqual(true);
    });
  });

  describe('faultReportConfiguration', () => {
    it('rejectsEmptyFaultDeviceCode', 0, () => {
      const result = FaultReportService.validateFaultReportForm({
        deviceCode: '',
        faultType: FaultType.OperationAbnormal,
        severity: FaultSeverity.General,
        occurredAt: '2026-05-28 16:30',
        description: '设备运行异常。',
        sceneCondition: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入设备编号');
    });

    it('rejectsEmptyFaultOccurredAt', 0, () => {
      const result = FaultReportService.validateFaultReportForm({
        deviceCode: 'RDVP-DEVICE-0001',
        faultType: FaultType.CommunicationFault,
        severity: FaultSeverity.Severe,
        occurredAt: '',
        description: '设备运行异常。',
        sceneCondition: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入发生时间');
    });

    it('rejectsEmptyFaultDescription', 0, () => {
      const result = FaultReportService.validateFaultReportForm({
        deviceCode: 'RDVP-DEVICE-0001',
        faultType: FaultType.LogicFault,
        severity: FaultSeverity.General,
        occurredAt: '2026-05-28 16:30',
        description: '',
        sceneCondition: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入故障描述');
    });

    it('acceptsCompleteFaultReportForm', 0, () => {
      const result = FaultReportService.validateFaultReportForm({
        deviceCode: 'RDVP-DEVICE-0001',
        faultType: FaultType.ExternalFactor,
        severity: FaultSeverity.Minor,
        occurredAt: '2026-05-28 16:30',
        description: '设备运行异常，需维修人员进一步检查。',
        sceneCondition: '现场已停止继续使用。'
      });

      expect(result.valid).assertEqual(true);
    });

    it('formatsUpdatedFaultCategories', 0, () => {
      expect(FaultReportService.formatFaultType(FaultType.CommunicationFault)).assertEqual('通信故障');
      expect(FaultReportService.formatFaultType(FaultType.EnergyFault)).assertEqual('能源故障');
      expect(FaultReportService.formatFaultTypeDescription(FaultType.LogicFault)).assertEqual('控制策略、业务规则、程序状态或参数配置异常，导致设备行为不符合预期');
      expect(FaultReportService.formatSeverity(FaultSeverity.Emergency)).assertEqual('紧急');
      expect(FaultReportService.formatSeverity(FaultSeverity.Minor)).assertEqual('轻微');
      expect(FaultReportService.formatSeverityDescription(FaultSeverity.Minor)).assertEqual('暂不影响正常使用，但存在缺陷、隐患或趋势性异常，应记录并跟踪处理');
    });
  });

  describe('repairTaskConfiguration', () => {
    it('usesTenKilometersAsDefaultRadius', 0, () => {
      expect(RepairTaskService.getDefaultRadiusKm()).assertEqual(10);
    });

    it('rejectsInvalidRepairTaskRadius', 0, () => {
      const result = RepairTaskService.validateAvailableRepairTaskQuery({
        radiusKm: 0,
        availability: RepairerAvailability.Idle
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('查询范围必须在1到100公里之间');
    });

    it('rejectsBusyRepairerWhenRefreshingNearbyFaults', 0, () => {
      const result = RepairTaskService.validateAvailableRepairTaskQuery({
        radiusKm: 10,
        availability: RepairerAvailability.Busy
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('仅空闲状态可刷新附近故障');
    });

    it('acceptsIdleRepairTaskQuery', 0, () => {
      const result = RepairTaskService.validateAvailableRepairTaskQuery({
        radiusKm: 10,
        availability: RepairerAvailability.Idle
      });

      expect(result.valid).assertEqual(true);
      expect(result.normalizedRadiusKm).assertEqual(10);
    });

    it('rejectsEmptyRepairTaskAcceptId', 0, () => {
      const result = RepairTaskService.validateRepairTaskId('');

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请选择需要接取的维修任务');
    });

    it('rejectsEmptyRepairReportTaskId', 0, () => {
      const result = RepairTaskService.validateRepairReportForm({
        taskId: '',
        result: RepairReportResult.Repaired,
        repairedAt: '2026-05-28 18:30',
        processDescription: '已完成维修并复测。',
        partsUsed: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入维修任务编号');
    });

    it('rejectsEmptyRepairReportProcess', 0, () => {
      const result = RepairTaskService.validateRepairReportForm({
        taskId: 'RDVP-REPAIR-0001',
        result: RepairReportResult.Repaired,
        repairedAt: '2026-05-28 18:30',
        processDescription: '',
        partsUsed: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入维修过程');
    });

    it('acceptsCompleteRepairReport', 0, () => {
      const result = RepairTaskService.validateRepairReportForm({
        taskId: 'RDVP-REPAIR-0001',
        result: RepairReportResult.TemporaryRestored,
        repairedAt: '2026-05-28 18:30',
        processDescription: '完成临时恢复，设备可限载运行，需后续更换部件。',
        partsUsed: '临时接线端子 1 个'
      });

      expect(result.valid).assertEqual(true);
      expect(RepairTaskService.formatRepairReportResult(RepairReportResult.TemporaryRestored)).assertEqual('临时恢复');
    });
  });
}
