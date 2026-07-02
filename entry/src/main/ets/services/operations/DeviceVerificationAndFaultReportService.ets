import { ApiResponse } from '../../models/common/ApiModels';
import { FaultStatus } from '../../models/operations/FaultModels';
import {
  DeviceVerificationForm,
  DeviceVerificationAndFaultReportForm,
  DeviceVerificationAndFaultReportResult,
  DeviceVerificationReport,
  DeviceVerificationValidationResult,
  VerificationResult
} from '../../models/operations/DeviceVerificationAndFaultReportModels';
import { ApiClient } from '../common/ApiClient';
import { DeviceService } from '../archive/DeviceService';
import { FaultReportService } from './FaultReportService';
import { UiFeedbackService } from '../common/UiFeedbackService';

const MAX_DESCRIPTION_LENGTH = 500;
const MAX_REMARK_LENGTH = 300;

interface DeviceVerificationReportApiResult {
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

interface DeviceVerificationAndFaultReportApiResult {
  verificationReport: DeviceVerificationReportApiResult;
  faultReport: FaultReportApiResult;
}

export class DeviceVerificationAndFaultReportService {
  static normalizeText(value: string): string {
    return value.trim();
  }

  static validateVerificationForm(form: DeviceVerificationForm): DeviceVerificationValidationResult {
    const deviceCodeValidation = DeviceService.validateDeviceCodeQuery({
      deviceCode: form.deviceCode
    });

    if (!deviceCodeValidation.valid) {
      return {
        valid: false,
        message: deviceCodeValidation.message
      };
    }

    if (!DeviceVerificationAndFaultReportService.isKnownResult(form.result)) {
      return {
        valid: false,
        message: UiFeedbackService.requiredSelection('核验结果')
      };
    }

    const verifiedAt = DeviceVerificationAndFaultReportService.normalizeText(form.verifiedAt);
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

    const description = DeviceVerificationAndFaultReportService.normalizeText(form.description);
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

    const remark = DeviceVerificationAndFaultReportService.normalizeText(form.remark ?? '');
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

  static validateVerificationAndFaultReportForm(form: DeviceVerificationAndFaultReportForm): DeviceVerificationValidationResult {
    const deviceCodeValidation = DeviceService.validateDeviceCodeQuery({
      deviceCode: form.verification.deviceCode
    });

    if (!deviceCodeValidation.valid) {
      return {
        valid: false,
        message: deviceCodeValidation.message
      };
    }

    if (!DeviceVerificationAndFaultReportService.isKnownResult(form.verification.result)) {
      return {
        valid: false,
        message: UiFeedbackService.requiredSelection('核验结果')
      };
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

    const verificationDescription = DeviceVerificationAndFaultReportService.resolveVerificationDescription(form);
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

  static async submitVerificationReportRemoteFirst(form: DeviceVerificationForm): Promise<ApiResponse<DeviceVerificationReport>> {
    const validation = DeviceVerificationAndFaultReportService.validateVerificationForm(form);
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
      return ApiClient.createServiceUnavailableResponse<DeviceVerificationReport>();
    }

    const verifiedAt = DeviceVerificationAndFaultReportService.normalizeText(form.verifiedAt);
    return DeviceVerificationAndFaultReportService.submitVerificationReportToBackend(form, verifiedAt);
  }

  static async submitVerificationAndFaultReportRemoteFirst(
    form: DeviceVerificationAndFaultReportForm
  ): Promise<ApiResponse<DeviceVerificationAndFaultReportResult>> {
    const validation = DeviceVerificationAndFaultReportService.validateVerificationAndFaultReportForm(form);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'DEVICE_VERIFICATION_FAULT_REPORT_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceVerificationAndFaultReportResult>();
    }

    const verifiedAt = FaultReportService.normalizeText(form.faultReport.occurredAt);
    return DeviceVerificationAndFaultReportService.submitVerificationAndFaultReportToBackend(form, verifiedAt);
  }

  private static async submitVerificationReportToBackend(
    form: DeviceVerificationForm,
    verifiedAt: string
  ): Promise<ApiResponse<DeviceVerificationReport>> {
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

    const response = await ApiClient.request<DeviceVerificationReportApiResult>(
      `/api/v1/devices/${encodeURIComponent(deviceResponse.data.id)}/verification-reports`,
      'POST',
      true,
      JSON.stringify({
        result: form.result,
        description: DeviceVerificationAndFaultReportService.normalizeText(form.description),
        remark: DeviceVerificationAndFaultReportService.normalizeText(form.remark ?? ''),
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

  private static async submitVerificationAndFaultReportToBackend(
    form: DeviceVerificationAndFaultReportForm,
    verifiedAt: string
  ): Promise<ApiResponse<DeviceVerificationAndFaultReportResult>> {
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

    const response = await ApiClient.request<DeviceVerificationAndFaultReportApiResult>(
      `/api/v1/devices/${encodeURIComponent(deviceResponse.data.id)}/verification-reports/fault-report`,
      'POST',
      true,
      JSON.stringify({
        result: form.verification.result,
        description: DeviceVerificationAndFaultReportService.resolveVerificationDescription(form),
        remark: DeviceVerificationAndFaultReportService.normalizeText(form.verification.remark ?? ''),
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
          code: 'DEVICE_VERIFICATION_FAULT_REPORT_RESPONSE_INVALID',
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

  private static isKnownResult(result: VerificationResult): boolean {
    return result === VerificationResult.Normal ||
      result === VerificationResult.Abnormal;
  }

  private static resolveVerificationDescription(form: DeviceVerificationAndFaultReportForm): string {
    const verificationDescription = DeviceVerificationAndFaultReportService.normalizeText(form.verification.description);
    if (verificationDescription.length > 0) {
      return verificationDescription;
    }

    return FaultReportService.normalizeText(form.faultReport.description);
  }
}
