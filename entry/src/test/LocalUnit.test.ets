import { describe, expect, it } from '@ohos/hypium';
import { DeviceStatus } from '../main/ets/models/archive/DeviceModels';
import { UiFeedbackTone } from '../main/ets/models/common/UiFeedbackModels';
import { UiFeedbackService } from '../main/ets/services/common/UiFeedbackService';
import { AuthService } from '../main/ets/services/identity/AuthService';
import { DeviceArchiveRequestService } from '../main/ets/services/archive/DeviceArchiveRequestService';
import { DeviceArchiveUpdateService } from '../main/ets/services/archive/DeviceArchiveUpdateService';
import { ApiClient } from '../main/ets/services/common/ApiClient';
import { RepairTaskService } from '../main/ets/services/operations/RepairTaskService';

export default function localUnitTest() {
  describe('uiFeedbackMessages', () => {
    it('formatsRequiredInputMessage', 0, () => {
      expect(UiFeedbackService.requiredInput('账号')).assertEqual('请输入账号');
    });

    it('formatsRequiredTimeMessage', 0, () => {
      expect(UiFeedbackService.requiredTime('审核')).assertEqual('请选择审核时间');
    });

    it('formatsIncorrectMessage', 0, () => {
      expect(UiFeedbackService.incorrect('密码')).assertEqual('密码不正确，请重新输入');
    });

    it('formatsOperationMessages', 0, () => {
      expect(UiFeedbackService.operationSuccess('登录')).assertEqual('登录成功');
      expect(UiFeedbackService.operationUnavailable('导出')).assertEqual('导出功能暂不可用，请稍后重试');
    });

    it('storesFeedbackToneAsStableSemanticValue', 0, () => {
      expect(UiFeedbackService.success('设置成功').tone).assertEqual(UiFeedbackTone.Success);
      expect(UiFeedbackService.danger('设置失败').tone).assertEqual(UiFeedbackTone.Danger);
      expect(UiFeedbackService.warning('设置提醒').tone).assertEqual(UiFeedbackTone.Warning);
      expect(UiFeedbackService.info('设置提示').tone).assertEqual(UiFeedbackTone.Info);
    });

    it('formatsLoginCredentialErrorsByField', 0, () => {
      expect(UiFeedbackService.loginError({
        code: 'ACCOUNT_INCORRECT',
        message: ''
      })).assertEqual('账号不正确，请重新输入');
      expect(UiFeedbackService.loginError({
        code: 'PASSWORD_INCORRECT',
        message: ''
      })).assertEqual('密码不正确，请重新输入');
    });

    it('removesForbiddenEndingPunctuation', 0, () => {
      expect(UiFeedbackService.sanitize('任务刷新失败，请稍后手动刷新。')).assertEqual('任务刷新失败，请稍后手动刷新');
      expect(UiFeedbackService.sanitize('当前位置未确认，暂不可接取？')).assertEqual('当前位置未确认，暂不可接取');
      expect(UiFeedbackService.sanitize('密码不正确，请重新输入，')).assertEqual('密码不正确，请重新输入，');
    });

    it('formatsUnavailableApiResponse', 0, () => {
      const response = ApiClient.createServiceUnavailableResponse<string>();

      expect(response.success).assertEqual(false);
      expect(response.error?.message).assertEqual('后端服务功能暂不可用，请稍后重试');
    });

    it('formatsTaskAcceptanceBusinessLimit', 0, () => {
      const response = RepairTaskService.createWorkloadSnapshot(3);

      expect(response.message).assertEqual('任务接取功能暂不可用，请稍后重试');
    });

    it('validatesTaskAcceptanceQueryAgainstProvidedWorkload', 0, () => {
      const result = RepairTaskService.validateTaskAcceptanceQuery({
        radiusKm: 20
      }, RepairTaskService.createWorkloadSnapshot(2));

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('查询范围不正确，请重新输入');
    });
  });

  describe('identityValidationFeedback', () => {
    it('validatesLoginFormByVisualOrder', 0, () => {
      const result = AuthService.validateLoginForm({
        username: '',
        password: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入账号');
    });
  });

  describe('archiveMutationValidation', () => {
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

    it('validatesArchiveCreateRequiresTime', 0, () => {
      const result = DeviceArchiveRequestService.validateCreateRequestForm({
        deviceCode: 'RDVP-DEVICE-0002',
        deviceName: 'B',
        model: 'M',
        manufacturer: 'Factory',
        locationAddress: 'Lab',
        reason: '新增设备',
        initiatedAt: ''
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请选择添加时间');
    });

    it('validatesArchiveCreateRequiresModel', 0, () => {
      const result = DeviceArchiveRequestService.validateCreateRequestForm({
        deviceCode: 'RDVP-DEVICE-0002',
        deviceName: 'B',
        model: '',
        manufacturer: 'Factory',
        locationAddress: 'Lab',
        reason: '新增设备',
        initiatedAt: '2026-06-22 10:00'
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入设备型号');
    });

    it('validatesArchiveCreateRequiresManufacturer', 0, () => {
      const result = DeviceArchiveRequestService.validateCreateRequestForm({
        deviceCode: 'RDVP-DEVICE-0002',
        deviceName: 'B',
        model: 'M',
        manufacturer: '',
        locationAddress: 'Lab',
        reason: '新增设备',
        initiatedAt: '2026-06-22 10:00'
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入生产厂商');
    });

    it('validatesArchiveCreateRequiresLocation', 0, () => {
      const result = DeviceArchiveRequestService.validateCreateRequestForm({
        deviceCode: 'RDVP-DEVICE-0002',
        deviceName: 'B',
        model: 'M',
        manufacturer: 'Factory',
        locationAddress: '',
        reason: '新增设备',
        initiatedAt: '2026-06-22 10:00'
      });

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请输入设备位置');
    });
  });
}
