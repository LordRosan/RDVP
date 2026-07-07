import { describe, expect, it } from '@ohos/hypium';
import { DeviceStatus } from '../main/ets/archive/models/DeviceModels';
import { UiFeedbackTone } from '../main/ets/shared/models/UiFeedbackModels';
import { AppColors, AppTone } from '../main/ets/shared/theme/AppTheme';
import { AppThemeMode } from '../main/ets/shared/theme/ThemeModels';
import { AppThemeService } from '../main/ets/shared/theme/AppThemeService';
import { HomeService } from '../main/ets/home/services/HomeService';
import { UiFeedbackService } from '../main/ets/shared/services/UiFeedbackService';
import { AuthService } from '../main/ets/user/services/AuthService';
import { ArchiveRequestService } from '../main/ets/archive/services/ArchiveRequestService';
import { ArchiveUpdateService } from '../main/ets/archive/services/ArchiveUpdateService';
import { ApiClient } from '../main/ets/shared/services/ApiClient';
import { RepairTaskService } from '../main/ets/operations/services/RepairTaskService';
import { AppNavigator } from '../main/ets/shared/navigation/AppNavigator';
import { AppRoutes } from '../main/ets/shared/navigation/AppRoutes';
import { LogCategory, LogQueryTab } from '../main/ets/log/models/LogQueryModels';
import { LogQueryService } from '../main/ets/log/services/LogQueryService';
import { ReinspectionService } from '../main/ets/operations/services/ReinspectionService';
import { ReinspectionTaskStatus } from '../main/ets/operations/models/ReinspectionModels';
import { VerificationReportService } from '../main/ets/operations/services/VerificationReportService';
import { FaultReportService, FaultTypeSelection } from '../main/ets/operations/services/FaultReportService';
import { LocationService } from '../main/ets/operations/services/LocationService';
import {
  AbnormalVerificationSubmissionForm,
  VerificationDeviceStatus,
  VerificationItemResult,
  VerificationMethod,
  VerificationReportForm,
  VerificationReportItem,
  VerificationResult,
  VerificationType
} from '../main/ets/operations/models/VerificationReportModels';
import { FaultReportForm, FaultSeverity, FaultSubtype, FaultType } from '../main/ets/operations/models/FaultModels';

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

    it('formatsLocationFailureMessagesBySystemErrorCode', 0, () => {
      expect(LocationService.formatLocationErrorMessage({
        code: 3301100,
        message: 'The location switch is off.'
      })).assertEqual('请先开启系统定位服务');
      expect(LocationService.formatLocationErrorMessage({
        code: 201,
        message: 'Permission verification failed.'
      })).assertEqual('请允许定位权限');
      expect(LocationService.formatLocationErrorMessage({
        code: 801,
        message: 'Capability not supported.'
      })).assertEqual('当前设备定位能力不可用');
      expect(LocationService.formatLocationErrorMessage({
        code: 3301000,
        message: 'The location service is unavailable.'
      })).assertEqual('当前设备定位服务不可用');
      expect(LocationService.formatLocationErrorMessage({
        code: 3301200,
        message: 'Failed to obtain the geographical location.'
      })).assertEqual('定位失败，请稍后重试');
    });

    it('convertsSystemLocationToBusinessCoordinates', 0, () => {
      const coordinates = LocationService.createCoordinatesFromValues(
        121.472644,
        31.231706,
        11.24,
        1782891759000
      );

      expect(coordinates === undefined).assertEqual(false);
      if (coordinates !== undefined) {
        expect(coordinates.longitude).assertEqual(121.472644);
        expect(coordinates.latitude).assertEqual(31.231706);
        expect(coordinates.accuracy).assertEqual(11.24);
        expect(coordinates.locatedAt).assertEqual('2026-07-01T07:42:39.000Z');
      }

      expect(LocationService.createCoordinatesFromValues(
        200,
        31.231706,
        11.24,
        1782891759000
      ) === undefined).assertEqual(true);
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

    it('usesDomainFirstRoutesForEntryPages', 0, () => {
      expect(AppRoutes.LoginPage).assertEqual('user/pages/LoginPage');
      expect(AppRoutes.HomePage).assertEqual('home/pages/HomePage');
      expect(AppRoutes.UserCenterPage).assertEqual('user/pages/UserCenterPage');
      expect(AppRoutes.UserSettingsPage).assertEqual('user/pages/UserSettingsPage');
      expect(AppRoutes.ArchiveCenterPage).assertEqual('archive/pages/ArchiveCenterPage');
      expect(AppRoutes.OperationsCenterPage).assertEqual('operations/pages/OperationsCenterPage');
      expect(AppRoutes.ReviewCenterPage).assertEqual('review/pages/ReviewCenterPage');
      expect(AppRoutes.LogCenterPage).assertEqual('log/pages/LogCenterPage');
      expect(AppRoutes.ArchiveQueryPage).assertEqual('archive/pages/ArchiveQueryPage');
      expect(AppRoutes.ArchiveCreatePage).assertEqual('archive/pages/ArchiveCreatePage');
      expect(AppRoutes.ArchiveDetailPage).assertEqual('archive/pages/ArchiveDetailPage');
      expect(AppRoutes.ArchiveExportPage).assertEqual('archive/pages/ArchiveExportPage');
      expect(AppRoutes.ArchiveUpdatePage).assertEqual('archive/pages/ArchiveUpdatePage');
      expect(AppRoutes.ArchiveDeletePage).assertEqual('archive/pages/ArchiveDeletePage');
      expect(AppRoutes.VerificationReportPage).assertEqual('operations/pages/VerificationReportPage');
      expect(AppRoutes.FaultReportPage).assertEqual('operations/pages/FaultReportPage');
      expect(AppRoutes.RepairAndReinspectionPage).assertEqual('operations/pages/RepairAndReinspectionPage');
      expect(AppRoutes.ArchiveLogQueryPage).assertEqual('log/pages/ArchiveLogQueryPage');
      expect(AppRoutes.OperationsLogQueryPage).assertEqual('log/pages/OperationsLogQueryPage');
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
      expect(LogQueryService.formatTypeLabel('ARCHIVE_EXPORT', LogCategory.ArchiveOperation)).assertEqual('档案导出');
      expect(LogQueryService.formatTypeLabel('DEVICE_VERIFICATION', LogCategory.OperationsOperation)).assertEqual('核验报告');
      expect(LogQueryService.formatTypeLabel('CREATE', LogCategory.ArchiveReview)).assertEqual('添加档案');
      expect(LogQueryService.formatTypeLabel('CREATE', LogCategory.ArchiveOperation)).assertEqual('档案添加');
    });

    it('formatsLogQueryTitlesByCategory', 0, () => {
      expect(LogQueryService.formatPageTitle(LogCategory.ArchiveOperation)).assertEqual('档案操作日志');
      expect(LogQueryService.formatPageTitle(LogCategory.ArchiveReview)).assertEqual('档案审核日志');
      expect(LogQueryService.formatListTitle(LogCategory.OperationsOperation)).assertEqual('运维操作日志列表');
      expect(LogQueryService.formatListTitle(LogCategory.OperationsReview)).assertEqual('运维审核日志列表');
    });

    it('formatsLogQuerySubtitlesByCategory', 0, () => {
      expect(LogQueryService.formatPageSubtitle(LogCategory.ArchiveOperation)).assertEqual('Archive Operation Logs');
      expect(LogQueryService.formatPageSubtitle(LogCategory.ArchiveReview)).assertEqual('Archive Review Logs');
      expect(LogQueryService.formatPageSubtitle(LogCategory.OperationsOperation)).assertEqual('Operations Operation Logs');
      expect(LogQueryService.formatPageSubtitle(LogCategory.OperationsReview)).assertEqual('Operations Review Logs');
    });

    it('resolvesLogQueryTabContextWithoutCurrentTabState', 0, () => {
      expect(LogQueryService.resolveArchiveCategory(LogQueryTab.Operation)).assertEqual(LogCategory.ArchiveOperation);
      expect(LogQueryService.resolveArchiveCategory(LogQueryTab.Review)).assertEqual(LogCategory.ArchiveReview);
      expect(LogQueryService.resolveOperationsCategory(LogQueryTab.Operation))
        .assertEqual(LogCategory.OperationsOperation);
      expect(LogQueryService.resolveOperationsCategory(LogQueryTab.Review)).assertEqual(LogCategory.OperationsReview);
      expect(LogQueryService.getArchiveLogTypeValues(LogQueryTab.Review).join('|'))
        .assertEqual('|CREATE|DELETE|UPDATE');
      expect(LogQueryService.getOperationsLogTypeValues(LogQueryTab.Operation).join('|'))
        .assertEqual('|DEVICE_VERIFICATION|FAULT_REPORT|REPAIR_TASK_ACCEPT|REPAIR_REPORT|REINSPECTION_REPORT');
      expect(LogQueryService.getOperationsLogTypeOptions(LogQueryTab.Review).join('|'))
        .assertEqual('全部|核验报告|报修报告|维修报告|复检报告');
    });

    it('formatsUnavailableDeviceCodeWithoutIncorrectMessage', 0, () => {
      expect(UiFeedbackService.deviceCodeAvailabilityMessage(false, '设备编号已被现有档案使用'))
        .assertEqual('设备编号不可用');
      expect(UiFeedbackService.deviceCodeAvailabilityMessage(true, '设备编号可用于添加档案'))
        .assertEqual('');
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

    it('validatesAbnormalVerificationStepRequiresVerificationFields', 0, () => {
      const items: VerificationReportItem[] = VerificationReportService.createDefaultVerificationItems()
        .map((item: VerificationReportItem): VerificationReportItem => {
          const verificationItem: VerificationReportItem = {
            itemCode: item.itemCode,
            itemName: item.itemName,
            result: item.itemCode === 'RUNNING_RESPONSE' ? VerificationItemResult.Failed : item.result
          };
          return verificationItem;
        });
      const form: VerificationReportForm = {
        deviceCode: 'RDVP-DEVICE-0001',
        verificationType: VerificationType.Routine,
        deviceStatus: VerificationDeviceStatus.Running,
        verificationMethod: VerificationMethod.OnsiteObservation,
        items,
        description: '',
        verifiedAt: ''
      };
      const result = VerificationReportService.validateAbnormalVerificationStepForm(form);

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请选择核验时间');
    });

    it('formatsVerificationStepActionByResult', 0, () => {
      expect(VerificationReportService.formatVerificationStepActionLabel('', false, false))
        .assertEqual('提交');
      expect(VerificationReportService.formatVerificationStepActionLabel(VerificationResult.Normal, false, false))
        .assertEqual('提交');
      expect(VerificationReportService.formatVerificationStepActionLabel(VerificationResult.Abnormal, false, false))
        .assertEqual('下一步');
    });

    it('resolvesVerificationPickerDisplayValues', 0, () => {
      expect(VerificationReportService.resolveVerificationTypeSelection('专项'))
        .assertEqual(VerificationType.Special);
      expect(VerificationReportService.resolveDeviceStatusSelection('未知'))
        .assertEqual(VerificationDeviceStatus.Unknown);
      expect(VerificationReportService.resolveVerificationMethodSelection('数据读取'))
        .assertEqual(VerificationMethod.DataReading);
    });

    it('resolvesFaultPickerDisplayValues', 0, () => {
      const faultSelection: FaultTypeSelection | undefined =
        FaultReportService.resolveFaultTypeSelection('运行异常', '无响应');
      expect(faultSelection === undefined).assertEqual(false);
      if (faultSelection !== undefined) {
        expect(faultSelection.faultType).assertEqual(FaultType.OperationAbnormal);
        expect(faultSelection.faultSubtype).assertEqual(FaultSubtype.NoResponse);
      }
      expect(FaultReportService.resolveSeveritySelection('严重')).assertEqual(FaultSeverity.Severe);
    });

    it('enablesAbnormalVerificationStepWithoutPassword', 0, () => {
      expect(VerificationReportService.canUseVerificationStepAction(VerificationResult.Abnormal, '', false, false))
        .assertEqual(true);
      expect(VerificationReportService.canUseVerificationStepAction(VerificationResult.Normal, '', false, false))
        .assertEqual(false);
      expect(VerificationReportService.canUseVerificationStepAction(VerificationResult.Normal, 'password', false, false))
        .assertEqual(true);
    });

    it('derivesVerificationResultFromItemResults', 0, () => {
      const items = VerificationReportService.createDefaultVerificationItems();
      expect(VerificationReportService.resolveVerificationResult(items)).assertEqual(VerificationResult.Normal);

      items[1].result = VerificationItemResult.Failed;
      expect(VerificationReportService.resolveVerificationResult(items)).assertEqual(VerificationResult.Abnormal);
    });

    it('rejectsVerificationItemsWithoutPassedOrFailedResult', 0, () => {
      const items: VerificationReportItem[] = VerificationReportService.createDefaultVerificationItems()
        .map((item: VerificationReportItem): VerificationReportItem => {
        const verificationItem: VerificationReportItem = {
          itemCode: item.itemCode,
          itemName: item.itemName,
          result: VerificationItemResult.NotApplicable
        };
        return verificationItem;
      });
      const form: VerificationReportForm = {
        deviceCode: 'RDVP-DEVICE-0001',
        verificationType: VerificationType.Routine,
        deviceStatus: VerificationDeviceStatus.Running,
        verificationMethod: VerificationMethod.OnsiteObservation,
        items,
        description: '现场核验完成',
        verifiedAt: '2026-07-07 10:00'
      };
      const result = VerificationReportService.validateVerificationForm(form);

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请选择核验项结果');
    });

    it('requiresFaultReportLocationCoordinates', 0, () => {
      const items: VerificationReportItem[] = VerificationReportService.createDefaultVerificationItems()
        .map((item: VerificationReportItem): VerificationReportItem => {
          const verificationItem: VerificationReportItem = {
            itemCode: item.itemCode,
            itemName: item.itemName,
            result: item.itemCode === 'RUNNING_RESPONSE' ? VerificationItemResult.Failed : item.result
          };
          return verificationItem;
        });
      const verification: VerificationReportForm = {
        deviceCode: 'RDVP-DEVICE-0001',
        verificationType: VerificationType.Routine,
        deviceStatus: VerificationDeviceStatus.Running,
        verificationMethod: VerificationMethod.OnsiteObservation,
        items,
        description: '运行响应异常',
        verifiedAt: '2026-07-07 10:00'
      };
      const faultReport: FaultReportForm = {
        deviceCode: 'RDVP-DEVICE-0001',
        faultType: FaultType.OperationAbnormal,
        faultSubtype: FaultSubtype.NoResponse,
        severity: FaultSeverity.General,
        occurredAt: '2026-07-07 10:10',
        description: '运行响应异常',
        sceneCondition: ''
      };
      const form: AbnormalVerificationSubmissionForm = {
        verification,
        faultReport
      };
      const result = VerificationReportService.validateAbnormalVerificationSubmissionForm(form);

      expect(result.valid).assertEqual(false);
      expect(result.message).assertEqual('请获取故障地点');
    });
  });

  describe('userLoginValidationFeedback', () => {
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
    it('usesSingleNativeTabsRouteForRepairAndReinspection', 0, () => {
      expect(HomeService.getRepairAndReinspectionRoute())
        .assertEqual('operations/pages/RepairAndReinspectionPage');
    });

    it('usesVerificationReportRouteAsOperationsEntry', 0, () => {
      expect(HomeService.getVerificationReportRoute()).assertEqual('operations/pages/VerificationReportPage');
      expect(HomeService.getFaultReportRoute()).assertEqual('operations/pages/FaultReportPage');
    });

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

    it('validatesArchiveCreateRequiresTime', 0, () => {
      const result = ArchiveRequestService.validateCreateRequestForm({
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
      const result = ArchiveRequestService.validateCreateRequestForm({
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
      const result = ArchiveRequestService.validateCreateRequestForm({
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
      const result = ArchiveRequestService.validateCreateRequestForm({
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
