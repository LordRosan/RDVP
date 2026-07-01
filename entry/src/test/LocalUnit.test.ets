import { describe, expect, it } from '@ohos/hypium';
import { DeviceStatus } from '../main/ets/models/archive/DeviceModels';
import { UiFeedbackTone } from '../main/ets/models/common/UiFeedbackModels';
import { AppColors, AppTone } from '../main/ets/styles/AppTheme';
import { AppThemeMode } from '../main/ets/models/app/ThemeModels';
import { AppThemeService } from '../main/ets/services/app/AppThemeService';
import { UiFeedbackService } from '../main/ets/services/common/UiFeedbackService';
import { AuthService } from '../main/ets/services/identity/AuthService';
import { DeviceArchiveRequestService } from '../main/ets/services/archive/DeviceArchiveRequestService';
import { DeviceArchiveUpdateService } from '../main/ets/services/archive/DeviceArchiveUpdateService';
import { ApiClient } from '../main/ets/services/common/ApiClient';
import { RepairTaskService } from '../main/ets/services/operations/RepairTaskService';
import { AppNavigator } from '../main/ets/utils/AppNavigator';
import { LogCategory } from '../main/ets/models/log/LogQueryModels';
import { LogQueryService } from '../main/ets/services/log/LogQueryService';
import { ReinspectionService } from '../main/ets/services/operations/ReinspectionService';
import { ReinspectionTaskStatus } from '../main/ets/models/operations/ReinspectionModels';

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

    it('mapsSemanticCenterTonesToMatchingSurfaces', 0, () => {
      expect(AppColors.colorForTone(AppTone.Primary)).assertEqual(AppColors.Primary);
      expect(AppColors.colorForTone(AppTone.Success)).assertEqual(AppColors.Success);
      expect(AppColors.colorForTone(AppTone.Warning)).assertEqual(AppColors.Warning);
      expect(AppColors.colorForTone(AppTone.Danger)).assertEqual(AppColors.Danger);
      expect(AppColors.colorForTone(AppTone.Log)).assertEqual(AppColors.Log);
      expect(AppColors.surfaceForTone(AppTone.Primary)).assertEqual(AppColors.PrimarySurface);
      expect(AppColors.surfaceForTone(AppTone.Success)).assertEqual(AppColors.SuccessSurface);
      expect(AppColors.surfaceForTone(AppTone.Warning)).assertEqual(AppColors.WarningSurface);
      expect(AppColors.surfaceForTone(AppTone.Danger)).assertEqual(AppColors.DangerSurface);
      expect(AppColors.surfaceForTone(AppTone.Log)).assertEqual(AppColors.LogSurface);
    });

    it('resolvesSemanticTonesAgainstCurrentThemeMode', 0, () => {
      AppThemeService.setThemeMode(AppThemeMode.Light);
      expect(AppThemeService.isDarkTheme()).assertEqual(false);
      expect(AppColors.surfaceForTone(AppTone.Success)).assertEqual('#E7F7F0');
      expect(AppColors.surfaceForTone(AppTone.Warning)).assertEqual('#FFF3DF');

      AppThemeService.setThemeMode(AppThemeMode.Dark);
      expect(AppThemeService.isDarkTheme()).assertEqual(true);
      expect(AppColors.surfaceForTone(AppTone.Success)).assertEqual('#14382F');
      expect(AppColors.surfaceForTone(AppTone.Warning)).assertEqual('#402D12');

      AppThemeService.setThemeMode(AppThemeMode.Light);
    });

    it('validatesTaskAcceptanceQueryAgainstProvidedWorkload', 0, () => {
      const result = RepairTaskService.validateTaskAcceptanceQuery({
        radiusKm: 20
      }, RepairTaskService.createWorkloadSnapshot(2));

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('查询范围不正确，请重新输入');
    });

    it('buildsLogQueryPathWithDateRange', 0, () => {
      const path = LogQueryService.buildLogQueryPath({
        category: LogCategory.OperationsOperation,
        type: 'REPAIR_REPORT',
        keyword: 'RDVP-DEVICE-0001',
        startDate: '2026-06-01',
        endDate: '2026-06-25',
        page: 1,
        pageSize: 50
      });

      expect(path).assertEqual('/api/v1/log-center/logs?category=OPERATIONS_OPERATION&page=1&pageSize=50&keyword=RDVP-DEVICE-0001&type=REPAIR_REPORT&startDate=2026-06-01&endDate=2026-06-25');
    });

    it('buildsDefaultLogQueryPathAfterFilterReset', 0, () => {
      const path = LogQueryService.buildLogQueryPath({
        category: LogCategory.ArchiveOperation,
        type: '',
        keyword: '',
        startDate: '',
        endDate: '',
        page: 1,
        pageSize: 50
      });

      expect(path).assertEqual('/api/v1/log-center/logs?category=ARCHIVE_OPERATION&page=1&pageSize=50');
    });

    it('formatsLogTypesForLogs', 0, () => {
      expect(LogQueryService.formatTypeLabel('DEVICE_ARCHIVE_EXPORT', LogCategory.ArchiveOperation)).assertEqual('档案导出');
      expect(LogQueryService.formatTypeLabel('DEVICE_VERIFICATION', LogCategory.OperationsOperation)).assertEqual('核验报告');
      expect(LogQueryService.formatTypeLabel('CREATE', LogCategory.ArchiveReview)).assertEqual('添加档案');
      expect(LogQueryService.formatTypeLabel('CREATE', LogCategory.ArchiveOperation)).assertEqual('档案添加');
    });

    it('formatsLogStatusesForSeedData', 0, () => {
      expect(LogQueryService.formatStatus('NORMAL')).assertEqual('正常');
      expect(LogQueryService.formatStatus('REPORT_SUBMITTED')).assertEqual('报告已提交');
      expect(LogQueryService.formatStatus('REPAIRED')).assertEqual('已修复');
      expect(LogQueryService.formatStatus('PASSED')).assertEqual('通过');
    });

    it('formatsReinspectionTaskStatusLabels', 0, () => {
      expect(ReinspectionService.formatTaskStatus(ReinspectionTaskStatus.Pending)).assertEqual('待复检');
      expect(ReinspectionService.formatTaskStatus(ReinspectionTaskStatus.Completed)).assertEqual('已完成');
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

  describe('appNavigation', () => {
    it('reportsRejectedNavigationPromises', 0, async (): Promise<void> => {
      let failed = false;

      void Promise.reject(new Error('route rejected')).catch(
        AppNavigator.createNavigationFailureHandler(() => {
          failed = true;
        }));
      await Promise.resolve();

      expect(failed).assertEqual(true);
    });

    it('ignoresResolvedNavigationPromises', 0, async (): Promise<void> => {
      let failed = false;

      void Promise.resolve().catch(
        AppNavigator.createNavigationFailureHandler(() => {
          failed = true;
        }));
      await Promise.resolve();

      expect(failed).assertEqual(false);
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
