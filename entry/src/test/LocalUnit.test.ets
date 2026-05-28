import { describe, it, expect } from '@ohos/hypium';
import { AuthService } from '../main/ets/services/AuthService';
import { DeviceService } from '../main/ets/services/DeviceService';
import { FaultSeverity, FaultType } from '../main/ets/models/FaultModels';
import { VerificationResult } from '../main/ets/models/VerificationModels';
import { FaultReportService } from '../main/ets/services/FaultReportService';
import { DeviceVerificationService } from '../main/ets/services/DeviceVerificationService';
import { WorkbenchActionId } from '../main/ets/models/WorkbenchModels';
import { WorkbenchService } from '../main/ets/services/WorkbenchService';

export default function localUnitTest() {
  describe('workbenchConfiguration', () => {
    it('providesCoreActions', 0, () => {
      const actions = WorkbenchService.getActions();

      expect(actions.length).assertEqual(7);
      expect(actions[0].id).assertEqual(WorkbenchActionId.DeviceQuery);
      expect(actions[0].title).assertEqual('设备查询');
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
        faultType: FaultType.OperationAbnormal,
        severity: FaultSeverity.General,
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
        faultType: FaultType.OperationAbnormal,
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
        faultType: FaultType.OperationAbnormal,
        severity: FaultSeverity.General,
        occurredAt: '2026-05-28 16:30',
        description: '设备运行异常，需维修人员进一步检查。',
        sceneCondition: '现场已停止继续使用。'
      });

      expect(result.valid).assertEqual(true);
    });
  });
}
