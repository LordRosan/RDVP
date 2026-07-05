import { ApiResponse } from '../../shared/models/ApiModels';
import { FaultStatus } from '../models/FaultModels';
import {
  VerificationReportForm,
  AbnormalVerificationSubmissionForm,
  AbnormalVerificationSubmissionResult,
  VerificationReportRecord,
  VerificationReportValidationResult,
  VerificationResult
} from '../models/VerificationReportModels';
import { ApiClient } from '../../shared/services/ApiClient';
import { DeviceService } from '../../archive/services/DeviceService';
import { FaultReportService } from './FaultReportService';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';

const MAX_DESCRIPTION_LENGTH = 500;
const MAX_REMARK_LENGTH = 300;

interface VerificationReportApiResult {
  id: string;
  result: string;
  description: string;
  remark?: string;
  verifiedAt: string;
  createdAt: string;
}

interface FaultReportApiResult {
  id: string;
  faultReportNo: string;
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

    if (!VerificationReportService.isKnownResult(form.result)) {
      return {
        valid: false,
        message: UiFeedbackService.requiredSelection('核验结果')
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

    if (form.result !== VerificationResult.Abnormal) {
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

    if (form.verification.result === VerificationResult.Normal) {
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
        message: UiFeedbackService.fieldTooLong('故障说明', 500, '字')
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
        result: form.result,
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
        result: response.data.result as VerificationResult,
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
        result: form.verification.result,
        description: VerificationReportService.resolveVerificationDescription(form),
        remark: VerificationReportService.normalizeText(form.verification.remark ?? ''),
        verifiedAt,
        faultType: form.faultReport.faultType,
        severity: form.faultReport.severity,
        occurredAt: FaultReportService.normalizeText(form.faultReport.occurredAt),
        faultDescription: FaultReportService.normalizeText(form.faultReport.description),
        sceneCondition: FaultReportService.normalizeText(form.faultReport.sceneCondition)
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
          result: response.data.verificationReport.result as VerificationResult,
          description: response.data.verificationReport.description,
          remark: response.data.verificationReport.remark,
          submittedAt: response.data.verificationReport.createdAt
        },
        faultReport: {
          id: response.data.faultReport.id,
          reportNo: response.data.faultReport.faultReportNo,
          deviceCode: DeviceService.normalizeDeviceCode(form.faultReport.deviceCode),
          faultType: form.faultReport.faultType,
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

  private static isKnownResult(result: VerificationResult): boolean {
    return result === VerificationResult.Normal ||
      result === VerificationResult.Abnormal;
  }

  private static resolveVerificationDescription(form: AbnormalVerificationSubmissionForm): string {
    const verificationDescription = VerificationReportService.normalizeText(form.verification.description);
    if (verificationDescription.length > 0) {
      return verificationDescription;
    }

    return FaultReportService.normalizeText(form.faultReport.description);
  }
}
