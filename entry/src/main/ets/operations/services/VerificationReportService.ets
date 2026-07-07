import { ApiResponse } from '../../shared/models/ApiModels';
import { FaultStatus } from '../models/FaultModels';
import {
  AbnormalVerificationSubmissionForm,
  AbnormalVerificationSubmissionResult,
  VerificationDeviceStatus,
  VerificationItemResult,
  VerificationMethod,
  VerificationReportForm,
  VerificationReportItem,
  VerificationReportRecord,
  VerificationReportValidationResult,
  VerificationResult,
  VerificationType
} from '../models/VerificationReportModels';
import { ApiClient } from '../../shared/services/ApiClient';
import { DeviceService } from '../../archive/services/DeviceService';
import { FaultReportService } from './FaultReportService';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';

const MAX_DESCRIPTION_LENGTH = 500;
const MAX_REMARK_LENGTH = 300;

const DEFAULT_VERIFICATION_ITEMS: VerificationReportItem[] = [
  {
    itemCode: 'IDENTIFICATION_CONSISTENCY',
    itemName: '标识一致性',
    result: VerificationItemResult.Passed
  },
  {
    itemCode: 'APPEARANCE_INTEGRITY',
    itemName: '外观完整性',
    result: VerificationItemResult.Passed
  },
  {
    itemCode: 'RUNNING_RESPONSE',
    itemName: '运行响应性',
    result: VerificationItemResult.Passed
  },
  {
    itemCode: 'CONNECTION_STABILITY',
    itemName: '连接稳定性',
    result: VerificationItemResult.Passed
  },
  {
    itemCode: 'DATA_CONSISTENCY',
    itemName: '数据一致性',
    result: VerificationItemResult.Passed
  },
  {
    itemCode: 'SAFETY_AVAILABILITY',
    itemName: '安全可用性',
    result: VerificationItemResult.Passed
  }
];

interface VerificationReportItemApiResult {
  itemCode: string;
  itemName: string;
  result: string;
}

interface VerificationReportApiResult {
  id: string;
  verificationType: string;
  deviceStatus: string;
  verificationMethod: string;
  result: string;
  items: VerificationReportItemApiResult[];
  description: string;
  remark?: string;
  verifiedAt: string;
  createdAt: string;
}

interface FaultReportApiResult {
  id: string;
  faultReportNo: string;
  faultSubtype: string;
  status: FaultStatus;
  createdAt: string;
}

interface AbnormalVerificationSubmissionApiResult {
  verificationReport: VerificationReportApiResult;
  faultReport: FaultReportApiResult;
}

export class VerificationReportService {
  static normalizeText(value: string): string {
    return value.trim();
  }

  static createDefaultVerificationItems(): VerificationReportItem[] {
    return DEFAULT_VERIFICATION_ITEMS.map((item: VerificationReportItem): VerificationReportItem => {
      const clonedItem: VerificationReportItem = {
        itemCode: item.itemCode,
        itemName: item.itemName,
        result: item.result
      };
      return clonedItem;
    });
  }

  static createEmptyAbnormalVerificationForm(): VerificationReportForm {
    const items = VerificationReportService.createDefaultVerificationItems();
    if (items.length > 0) {
      items[0].result = VerificationItemResult.Failed;
    }

    const form: VerificationReportForm = {
      deviceCode: '',
      verificationType: VerificationType.Routine,
      deviceStatus: VerificationDeviceStatus.Unknown,
      verificationMethod: VerificationMethod.OnsiteObservation,
      items,
      description: '',
      verifiedAt: '',
      remark: ''
    };
    return form;
  }

  static validateVerificationForm(form: VerificationReportForm): VerificationReportValidationResult {
    const deviceCodeValidation = DeviceService.validateDeviceCodeQuery({
      deviceCode: form.deviceCode
    });

    if (!deviceCodeValidation.valid) {
      return {
        valid: false,
        message: deviceCodeValidation.message
      };
    }

    const verifiedAt = VerificationReportService.normalizeText(form.verifiedAt);
    if (verifiedAt.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredTime('核验')
      };
    }

    if (verifiedAt.length > 64) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('核验时间', 64, '字')
      };
    }

    if (!VerificationReportService.isKnownVerificationType(form.verificationType)) {
      return {
        valid: false,
        message: UiFeedbackService.requiredSelection('核验类型')
      };
    }

    if (!VerificationReportService.isKnownDeviceStatus(form.deviceStatus)) {
      return {
        valid: false,
        message: UiFeedbackService.requiredSelection('设备状态')
      };
    }

    if (!VerificationReportService.isKnownVerificationMethod(form.verificationMethod)) {
      return {
        valid: false,
        message: UiFeedbackService.requiredSelection('核验方式')
      };
    }

    const itemsValidation = VerificationReportService.validateVerificationItems(form.items);
    if (!itemsValidation.valid) {
      return itemsValidation;
    }

    const description = VerificationReportService.normalizeText(form.description);
    if (description.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('核验说明')
      };
    }

    if (description.length > MAX_DESCRIPTION_LENGTH) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('核验说明', 500, '字')
      };
    }

    const remark = VerificationReportService.normalizeText(form.remark ?? '');
    if (remark.length > MAX_REMARK_LENGTH) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('备注', 300, '字')
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static validateAbnormalVerificationStepForm(form: VerificationReportForm): VerificationReportValidationResult {
    const verificationValidation = VerificationReportService.validateVerificationForm(form);
    if (!verificationValidation.valid) {
      return verificationValidation;
    }

    if (VerificationReportService.resolveVerificationResult(form.items) !== VerificationResult.Abnormal) {
      return {
        valid: false,
        message: UiFeedbackService.operationUnavailable('下一步')
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static validateAbnormalVerificationSubmissionForm(
    form: AbnormalVerificationSubmissionForm
  ): VerificationReportValidationResult {
    const verificationValidation = VerificationReportService.validateVerificationForm(form.verification);
    if (!verificationValidation.valid) {
      return verificationValidation;
    }

    if (VerificationReportService.resolveVerificationResult(form.verification.items) === VerificationResult.Normal) {
      return {
        valid: false,
        message: UiFeedbackService.operationUnavailable('提交')
      };
    }

    const faultReportValidation = FaultReportService.validateFaultReportForm(form.faultReport);
    if (!faultReportValidation.valid) {
      return {
        valid: false,
        message: faultReportValidation.message
      };
    }

    const verificationDescription = VerificationReportService.resolveVerificationDescription(form);
    if (verificationDescription.length > MAX_DESCRIPTION_LENGTH) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('核验说明', 500, '字')
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static async submitVerificationReportRemoteFirst(
    form: VerificationReportForm
  ): Promise<ApiResponse<VerificationReportRecord>> {
    const validation = VerificationReportService.validateVerificationForm(form);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'DEVICE_VERIFICATION_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<VerificationReportRecord>();
    }

    const verifiedAt = VerificationReportService.normalizeText(form.verifiedAt);
    return VerificationReportService.submitVerificationReportToBackend(form, verifiedAt);
  }

  static async submitAbnormalVerificationRemoteFirst(
    form: AbnormalVerificationSubmissionForm
  ): Promise<ApiResponse<AbnormalVerificationSubmissionResult>> {
    const validation = VerificationReportService.validateAbnormalVerificationSubmissionForm(form);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'ABNORMAL_VERIFICATION_SUBMISSION_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<AbnormalVerificationSubmissionResult>();
    }

    const verifiedAt = VerificationReportService.normalizeText(form.verification.verifiedAt);
    return VerificationReportService.submitAbnormalVerificationToBackend(form, verifiedAt);
  }

  private static async submitVerificationReportToBackend(
    form: VerificationReportForm,
    verifiedAt: string
  ): Promise<ApiResponse<VerificationReportRecord>> {
    const deviceResponse = await DeviceService.queryByCodeRemoteFirst({
      deviceCode: form.deviceCode
    });
    if (!deviceResponse.success || deviceResponse.data === undefined) {
      return {
        success: false,
        error: deviceResponse.error,
        requestId: deviceResponse.requestId,
        timestamp: deviceResponse.timestamp
      };
    }

    const response = await ApiClient.request<VerificationReportApiResult>(
      `/api/v1/devices/${encodeURIComponent(deviceResponse.data.id)}/verification-reports`,
      'POST',
      true,
      JSON.stringify({
        result: VerificationReportService.resolveVerificationResult(form.items),
        verificationType: form.verificationType,
        deviceStatus: form.deviceStatus,
        verificationMethod: form.verificationMethod,
        items: VerificationReportService.createRequestItems(form.items),
        description: VerificationReportService.normalizeText(form.description),
        remark: VerificationReportService.normalizeText(form.remark ?? ''),
        verifiedAt
      })
    );

    if (!response.success) {
      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    if (response.data === undefined) {
      return {
        success: false,
        error: {
          code: 'DEVICE_VERIFICATION_RESPONSE_INVALID',
          message: UiFeedbackService.operationUnavailable('提交')
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: {
        id: response.data.id,
        deviceCode: DeviceService.normalizeDeviceCode(form.deviceCode),
        verificationType: response.data.verificationType as VerificationType,
        deviceStatus: response.data.deviceStatus as VerificationDeviceStatus,
        verificationMethod: response.data.verificationMethod as VerificationMethod,
        result: response.data.result as VerificationResult,
        items: VerificationReportService.toRecordItems(response.data.items),
        description: response.data.description,
        remark: response.data.remark,
        submittedAt: response.data.createdAt
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  private static async submitAbnormalVerificationToBackend(
    form: AbnormalVerificationSubmissionForm,
    verifiedAt: string
  ): Promise<ApiResponse<AbnormalVerificationSubmissionResult>> {
    const deviceResponse = await DeviceService.queryByCodeRemoteFirst({
      deviceCode: form.verification.deviceCode
    });
    if (!deviceResponse.success || deviceResponse.data === undefined) {
      return {
        success: false,
        error: deviceResponse.error,
        requestId: deviceResponse.requestId,
        timestamp: deviceResponse.timestamp
      };
    }

    const response = await ApiClient.request<AbnormalVerificationSubmissionApiResult>(
      `/api/v1/devices/${encodeURIComponent(deviceResponse.data.id)}/verification-reports/fault-report`,
      'POST',
      true,
      JSON.stringify({
        result: VerificationReportService.resolveVerificationResult(form.verification.items),
        verificationType: form.verification.verificationType,
        deviceStatus: form.verification.deviceStatus,
        verificationMethod: form.verification.verificationMethod,
        items: VerificationReportService.createRequestItems(form.verification.items),
        description: VerificationReportService.resolveVerificationDescription(form),
        remark: VerificationReportService.normalizeText(form.verification.remark ?? ''),
        verifiedAt,
        faultType: form.faultReport.faultType,
        faultSubtype: form.faultReport.faultSubtype,
        severity: form.faultReport.severity,
        occurredAt: FaultReportService.normalizeText(form.faultReport.occurredAt),
        faultDescription: FaultReportService.normalizeText(form.faultReport.description),
        sceneCondition: FaultReportService.normalizeText(form.faultReport.sceneCondition),
        longitude: form.faultReport.longitude,
        latitude: form.faultReport.latitude
      })
    );

    if (!response.success) {
      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    if (response.data === undefined) {
      return {
        success: false,
        error: {
          code: 'ABNORMAL_VERIFICATION_SUBMISSION_RESPONSE_INVALID',
          message: UiFeedbackService.operationUnavailable('提交')
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: {
        verificationReport: {
          id: response.data.verificationReport.id,
          deviceCode: DeviceService.normalizeDeviceCode(form.verification.deviceCode),
          verificationType: response.data.verificationReport.verificationType as VerificationType,
          deviceStatus: response.data.verificationReport.deviceStatus as VerificationDeviceStatus,
          verificationMethod: response.data.verificationReport.verificationMethod as VerificationMethod,
          result: response.data.verificationReport.result as VerificationResult,
          items: VerificationReportService.toRecordItems(response.data.verificationReport.items),
          description: response.data.verificationReport.description,
          remark: response.data.verificationReport.remark,
          submittedAt: response.data.verificationReport.createdAt
        },
        faultReport: {
          id: response.data.faultReport.id,
          reportNo: response.data.faultReport.faultReportNo,
          deviceCode: DeviceService.normalizeDeviceCode(form.faultReport.deviceCode),
          faultType: form.faultReport.faultType,
          faultSubtype: form.faultReport.faultSubtype,
          severity: form.faultReport.severity,
          status: response.data.faultReport.status as FaultStatus,
          submittedAt: response.data.faultReport.createdAt
        }
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static formatVerificationResult(result: VerificationResult): string {
    switch (result) {
      case VerificationResult.Normal:
        return '正常';
      case VerificationResult.Abnormal:
        return '异常';
      default:
        return '-';
    }
  }

  static formatVerificationType(type: VerificationType): string {
    switch (type) {
      case VerificationType.Routine:
        return '例行';
      case VerificationType.Temporary:
        return '临时';
      case VerificationType.Special:
        return '专项';
      case VerificationType.Initial:
        return '首次';
      case VerificationType.Sampling:
        return '抽检';
      case VerificationType.Other:
        return '其他';
      default:
        return '-';
    }
  }

  static formatDeviceStatus(status: VerificationDeviceStatus): string {
    switch (status) {
      case VerificationDeviceStatus.Running:
        return '运行';
      case VerificationDeviceStatus.Standby:
        return '待机';
      case VerificationDeviceStatus.Stopped:
        return '停机';
      case VerificationDeviceStatus.Offline:
        return '离线';
      case VerificationDeviceStatus.Unknown:
        return '未知';
      case VerificationDeviceStatus.Other:
        return '其他';
      default:
        return '-';
    }
  }

  static formatVerificationMethod(method: VerificationMethod): string {
    switch (method) {
      case VerificationMethod.OnsiteObservation:
        return '现场观察';
      case VerificationMethod.IdentificationCheck:
        return '编号核对';
      case VerificationMethod.FunctionTest:
        return '功能测试';
      case VerificationMethod.DataReading:
        return '数据读取';
      case VerificationMethod.RemoteConfirmation:
        return '远程确认';
      case VerificationMethod.Other:
        return '其他方式';
      default:
        return '-';
    }
  }

  static formatVerificationItemResult(result: VerificationItemResult): string {
    switch (result) {
      case VerificationItemResult.Passed:
        return '通过';
      case VerificationItemResult.Failed:
        return '未通过';
      case VerificationItemResult.NotApplicable:
        return '不适用';
      default:
        return '-';
    }
  }

  static resolveVerificationResult(items: VerificationReportItem[]): VerificationResult {
    for (let index = 0; index < items.length; index++) {
      if (items[index].result === VerificationItemResult.Failed) {
        return VerificationResult.Abnormal;
      }
    }

    return VerificationResult.Normal;
  }

  static formatVerificationStepActionLabel(result: string, submitting: boolean, submitted: boolean): string {
    if (submitting) {
      return '提交中';
    }

    if (submitted) {
      return '已提交';
    }

    return VerificationReportService.isAbnormalResult(result) ? '下一步' : '提交';
  }

  static canUseVerificationStepAction(
    result: string,
    password: string,
    submitting: boolean,
    submitted: boolean
  ): boolean {
    if (submitting || submitted || result.length === 0) {
      return false;
    }

    if (VerificationReportService.isAbnormalResult(result)) {
      return true;
    }

    return result === VerificationResult.Normal && password.length > 0;
  }

  static isAbnormalResult(result: string): boolean {
    return result === VerificationResult.Abnormal;
  }

  private static validateVerificationItems(items: VerificationReportItem[]): VerificationReportValidationResult {
    if (items.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredSelection('核验项')
      };
    }

    let hasEffectiveResult = false;
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      if (VerificationReportService.normalizeText(item.itemCode).length === 0 ||
        VerificationReportService.normalizeText(item.itemName).length === 0 ||
        !VerificationReportService.isKnownItemResult(item.result)) {
        return {
          valid: false,
          message: UiFeedbackService.requiredSelection('核验项结果')
        };
      }

      if (item.result === VerificationItemResult.Passed || item.result === VerificationItemResult.Failed) {
        hasEffectiveResult = true;
      }
    }

    if (!hasEffectiveResult) {
      return {
        valid: false,
        message: UiFeedbackService.requiredSelection('核验项结果')
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  private static createRequestItems(items: VerificationReportItem[]): VerificationReportItem[] {
    return items.map((item: VerificationReportItem): VerificationReportItem => {
      const requestItem: VerificationReportItem = {
        itemCode: VerificationReportService.normalizeText(item.itemCode),
        itemName: VerificationReportService.normalizeText(item.itemName),
        result: item.result
      };
      return requestItem;
    });
  }

  private static toRecordItems(items: VerificationReportItemApiResult[] | undefined): VerificationReportItem[] {
    if (items === undefined) {
      return [];
    }

    return items.map((item: VerificationReportItemApiResult): VerificationReportItem => {
      const recordItem: VerificationReportItem = {
        itemCode: item.itemCode,
        itemName: item.itemName,
        result: item.result as VerificationItemResult
      };
      return recordItem;
    });
  }

  private static isKnownVerificationType(type: VerificationType): boolean {
    return type === VerificationType.Routine ||
      type === VerificationType.Temporary ||
      type === VerificationType.Special ||
      type === VerificationType.Initial ||
      type === VerificationType.Sampling ||
      type === VerificationType.Other;
  }

  private static isKnownDeviceStatus(status: VerificationDeviceStatus): boolean {
    return status === VerificationDeviceStatus.Running ||
      status === VerificationDeviceStatus.Standby ||
      status === VerificationDeviceStatus.Stopped ||
      status === VerificationDeviceStatus.Offline ||
      status === VerificationDeviceStatus.Unknown ||
      status === VerificationDeviceStatus.Other;
  }

  private static isKnownVerificationMethod(method: VerificationMethod): boolean {
    return method === VerificationMethod.OnsiteObservation ||
      method === VerificationMethod.IdentificationCheck ||
      method === VerificationMethod.FunctionTest ||
      method === VerificationMethod.DataReading ||
      method === VerificationMethod.RemoteConfirmation ||
      method === VerificationMethod.Other;
  }

  private static isKnownItemResult(result: VerificationItemResult): boolean {
    return result === VerificationItemResult.Passed ||
      result === VerificationItemResult.Failed ||
      result === VerificationItemResult.NotApplicable;
  }

  private static resolveVerificationDescription(form: AbnormalVerificationSubmissionForm): string {
    const verificationDescription = VerificationReportService.normalizeText(form.verification.description);
    if (verificationDescription.length > 0) {
      return verificationDescription;
    }

    return FaultReportService.normalizeText(form.faultReport.description);
  }
}
