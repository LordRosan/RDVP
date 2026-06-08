import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { util } from '@kit.ArkTS';
import { ApiErrorCode, ApiResponse } from '../models/ApiModels';
import { ApiClient } from './ApiClient';

const MEDIA_WRITE_PERMISSION: Permissions = 'ohos.permission.WRITE_IMAGEVIDEO';

export interface DeviceQrCodeExportForm {
  deviceId: string;
  password: string;
}

export interface DeviceQrCodeExportResult {
  deviceId: string;
  deviceCode: string;
  fileName: string;
  qrImageBase64: string;
  qrContentDigest: string;
  exportedAt: string;
}

export class DeviceQrCodeExportService {
  static async exportQrCodeRemoteFirst(form: DeviceQrCodeExportForm): Promise<ApiResponse<DeviceQrCodeExportResult>> {
    const validationMessage = DeviceQrCodeExportService.validateForm(form);
    if (validationMessage.length > 0) {
      return {
        success: false,
        error: {
          code: ApiErrorCode.ValidationFailed,
          message: validationMessage
        },
        timestamp: new Date().toISOString()
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceQrCodeExportResult>();
    }

    const deviceId = encodeURIComponent(form.deviceId.trim());
    return ApiClient.request<DeviceQrCodeExportResult>(
      `/api/v1/devices/${deviceId}/qrcode-export`,
      'POST',
      true,
      JSON.stringify({
        password: form.password
      }),
      false
    );
  }

  static async saveImageToGallery(
    context: common.Context,
    result: DeviceQrCodeExportResult
  ): Promise<ApiResponse<string>> {
    if (result.qrImageBase64.trim().length === 0) {
      return DeviceQrCodeExportService.createFailureResponse('二维码图片数据无效');
    }

    let tempFilePath = '';
    try {
      const mediaWriteGranted = await DeviceQrCodeExportService.requestMediaWritePermission(context);
      if (!mediaWriteGranted) {
        return DeviceQrCodeExportService.createFailureResponse('请授权相册写入权限后再导出二维码');
      }

      const fileName = DeviceQrCodeExportService.normalizeFileName(result.fileName, result.deviceCode);
      const filePath = `${context.cacheDir}/${fileName}`;
      tempFilePath = filePath;
      const base64 = new util.Base64Helper();
      const bytes = base64.decodeSync(result.qrImageBase64.trim());
      const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        const data = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
        fileIo.writeSync(file.fd, data);
      } finally {
        fileIo.closeSync(file);
      }

      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      try {
        const request = photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(
          context,
          fileUri.getUriFromPath(filePath)
        );
        await helper.applyChanges(request);
      } finally {
        await helper.release();
      }

      return {
        success: true,
        data: fileName,
        requestId: 'local-qrcode-export-save',
        timestamp: new Date().toISOString()
      };
    } catch (err) {
      return DeviceQrCodeExportService.createFailureResponse('二维码保存失败，请检查相册写入权限');
    } finally {
      DeviceQrCodeExportService.deleteTempFile(tempFilePath);
    }
  }

  static getImageDataUri(result: DeviceQrCodeExportResult): string {
    if (result.qrImageBase64.trim().length === 0) {
      return '';
    }

    return `data:image/png;base64,${result.qrImageBase64.trim()}`;
  }

  static formatDigest(result: DeviceQrCodeExportResult): string {
    const digest = result.qrContentDigest.trim();
    if (digest.length <= 12) {
      return digest.length === 0 ? '-' : digest;
    }

    return `${digest.substring(0, 6)}...${digest.substring(digest.length - 6)}`;
  }

  private static validateForm(form: DeviceQrCodeExportForm): string {
    if (form.deviceId.trim().length === 0) {
      return '未获取设备档案';
    }

    if (form.password.length === 0) {
      return '请输入当前账号密码';
    }

    return '';
  }

  private static normalizeFileName(fileName: string, deviceCode: string): string {
    const source = fileName.trim().length > 0 ? fileName.trim() : `${deviceCode}.png`;
    const safeName = source.replace(/[\\/:*?"<>|]/g, '_');
    return safeName.toLowerCase().endsWith('.png') ? safeName : `${safeName}.png`;
  }

  private static createFailureResponse(message: string): ApiResponse<string> {
    return {
      success: false,
      error: {
        code: ApiErrorCode.InternalError,
        message
      },
      timestamp: new Date().toISOString()
    };
  }

  private static deleteTempFile(filePath: string): void {
    if (filePath.length === 0) {
      return;
    }

    try {
      fileIo.unlinkSync(filePath);
    } catch (err) {
    }
  }

  private static async requestMediaWritePermission(context: common.Context): Promise<boolean> {
    try {
      const result = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(context, [MEDIA_WRITE_PERMISSION]);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (err) {
      return false;
    }
  }
}
