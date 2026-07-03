import { ApiError } from '../models/ApiModels';
import { UiFeedbackMessage, UiFeedbackTone } from '../models/UiFeedbackModels';

export class UiFeedbackService {
  static sanitize(message: string): string {
    let text = message.trim();
    while (text.length > 0 && UiFeedbackService.isForbiddenEndingPunctuation(text.charAt(text.length - 1))) {
      text = text.substring(0, text.length - 1).trim();
    }
    return text;
  }

  static requiredInput(label: string): string {
    return `请输入${UiFeedbackService.normalizeLabel(label)}`;
  }

  static requiredSelection(label: string): string {
    return `请选择${UiFeedbackService.normalizeLabel(label)}`;
  }

  static requiredTime(label: string): string {
    const normalizedLabel = UiFeedbackService.normalizeLabel(label);
    if (normalizedLabel.endsWith('时间')) {
      return `请选择${normalizedLabel}`;
    }
    return `请选择${normalizedLabel}时间`;
  }

  static incorrect(label: string): string {
    return `${UiFeedbackService.normalizeLabel(label)}不正确，请重新输入`;
  }

  static unavailable(actionName: string): string {
    return UiFeedbackService.operationUnavailable(actionName);
  }

  static operationSuccess(actionName: string): string {
    return `${UiFeedbackService.normalizeLabel(actionName)}成功`;
  }

  static operationUnavailable(actionName: string): string {
    return `${UiFeedbackService.normalizeLabel(actionName)}功能暂不可用，请稍后重试`;
  }

  static fieldTooLong(label: string, limit: number, unit: string = '个字符'): string {
    return `${UiFeedbackService.normalizeLabel(label)}不能超过${limit}${unit}`;
  }

  static message(message: string, tone: UiFeedbackTone): UiFeedbackMessage {
    return {
      message: UiFeedbackService.sanitize(message),
      tone
    };
  }

  static success(message: string): UiFeedbackMessage {
    return UiFeedbackService.message(message, UiFeedbackTone.Success);
  }

  static danger(message: string): UiFeedbackMessage {
    return UiFeedbackService.message(message, UiFeedbackTone.Danger);
  }

  static warning(message: string): UiFeedbackMessage {
    return UiFeedbackService.message(message, UiFeedbackTone.Warning);
  }

  static info(message: string): UiFeedbackMessage {
    return UiFeedbackService.message(message, UiFeedbackTone.Info);
  }

  static successFor(actionName: string): UiFeedbackMessage {
    return UiFeedbackService.success(UiFeedbackService.operationSuccess(actionName));
  }

  static unavailableFor(actionName: string): UiFeedbackMessage {
    return UiFeedbackService.danger(UiFeedbackService.operationUnavailable(actionName));
  }

  static fallbackError(error: ApiError | undefined, actionName: string): string {
    if (error === undefined || error.message.trim().length === 0) {
      return UiFeedbackService.operationUnavailable(actionName);
    }

    return UiFeedbackService.sanitize(error.message);
  }

  static operationError(error: ApiError | undefined, actionName: string): string {
    if (error === undefined) {
      return UiFeedbackService.operationUnavailable(actionName);
    }

    const code = `${error.code}`;
    if (UiFeedbackService.isValidationCode(code)) {
      return UiFeedbackService.fallbackError(error, actionName);
    }

    if (code === 'PASSWORD_REQUIRED') {
      return UiFeedbackService.requiredInput('密码');
    }

    if (code === 'UNAUTHORIZED') {
      return UiFeedbackService.operationUnavailable(actionName);
    }

    if (code === 'FORBIDDEN') {
      return UiFeedbackService.operationUnavailable(actionName);
    }

    return UiFeedbackService.operationUnavailable(actionName);
  }

  static loginError(error: ApiError | undefined): string {
    const code = error === undefined ? '' : `${error.code}`;
    if (code === 'ACCOUNT_INCORRECT') {
      return UiFeedbackService.incorrect('账号');
    }

    if (code === 'PASSWORD_INCORRECT') {
      return UiFeedbackService.incorrect('密码');
    }

    return UiFeedbackService.operationError(error, '登录');
  }

  static passwordVerificationError(error: ApiError | undefined, actionName: string): string {
    const code = error === undefined ? '' : `${error.code}`;
    if (code === 'PASSWORD_REQUIRED') {
      return UiFeedbackService.requiredInput('密码');
    }

    if (code === 'PASSWORD_INCORRECT') {
      return UiFeedbackService.incorrect('密码');
    }

    return UiFeedbackService.operationUnavailable(actionName);
  }

  static codeQueryError(error: ApiError | undefined, fieldName: string, actionName: string): string {
    const code = error === undefined ? '' : `${error.code}`;
    if (code === 'DEVICE_CODE_INVALID' || code === 'DEVICE_NOT_FOUND' ||
      UiFeedbackService.isValidationCode(code) || code === 'BAD_REQUEST' || code === 'NOT_FOUND') {
      return UiFeedbackService.incorrect(fieldName);
    }

    return UiFeedbackService.operationUnavailable(actionName);
  }

  static deviceCodeAvailabilityMessage(available: boolean, reason?: string): string {
    if (available) {
      return '';
    }

    return '设备编号不可用';
  }

  static qrQueryError(error: ApiError | undefined, actionName: string): string {
    const code = error === undefined ? '' : `${error.code}`;
    if (code === 'DEVICE_NOT_FOUND' || code.startsWith('QR_') || UiFeedbackService.isValidationCode(code) ||
      code === 'BAD_REQUEST' || code === 'NOT_FOUND') {
      return UiFeedbackService.incorrect('二维码');
    }

    return UiFeedbackService.operationUnavailable(actionName);
  }

  static requiredAction(actionName: string): string {
    return `请${UiFeedbackService.normalizeLabel(actionName)}`;
  }

  private static normalizeLabel(label: string): string {
    return UiFeedbackService.sanitize(label);
  }

  private static isForbiddenEndingPunctuation(char: string): boolean {
    return char === '。' || char === '！' || char === '？' || char === '!' || char === '?' || char === '.' ||
      char === '…';
  }

  private static isValidationCode(code: string): boolean {
    return code.indexOf('INVALID') >= 0 || code.indexOf('REQUIRED') >= 0 || code.indexOf('VALIDATION') >= 0;
  }
}
