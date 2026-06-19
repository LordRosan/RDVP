import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { ApiErrorCode } from '../../models/common/ApiModels';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { ApiClient } from '../../services/common/ApiClient';
import { DeviceService } from '../../services/archive/DeviceService';
import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AuthGuard } from '../../utils/AuthGuard';

interface CodeAvailabilityResult {
  available: boolean;
  reason?: string;
}

@Entry
@Component
struct DeviceArchiveCodeVerify {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State deviceCode: string = '';
  @State message: string = '';
  @State verifying: boolean = false;
  @State result: CodeAvailabilityResult | undefined = undefined;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveCreateRequestSubmit)) {
      return;
    }
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: AppSpacing.Section }) {
          this.ModeHeader()
          this.VerifyForm()
          if (this.result !== undefined) {
            this.ResultPanel()
          }
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .padding({
          left: AppSpacing.PageX,
          right: AppSpacing.PageX,
          top: 0,
          bottom: AppSpacing.PageBottom
        })
        .width('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    this.backToArchiveCenter();
    return true;
  }

  @Builder
  PageTitleBar() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(22)
          .fontColor([AppColors.TextPrimary])
      }
      .width(44)
      .height(44)
      .backgroundColor(AppColors.SurfaceRaised)
      .border({ width: 1, color: AppColors.Divider })
      .onClick(() => {
        this.backToArchiveCenter();
      })
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: AppSpacing.PageX,
      right: AppSpacing.PageX
    })
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  ModeHeader() {
    Column({ space: 5 }) {
      Text('设备编号核验')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Device Code Verification')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({
      left: 0,
      right: 0,
      top: 12,
      bottom: 6
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  VerifyForm() {
    Column({ space: 16 }) {
      TextInput({
        placeholder: 'RDVP-DEVICE-XXXX',
        text: this.deviceCode
      })
        .height(56)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.verifying)
        .onChange((value: string) => {
          if (this.verifying) {
            return;
          }

          this.deviceCode = value;
          this.message = '';
          this.result = undefined;
        })

      this.MessageText()
      this.VerifySubmitButton(() => {
        this.verifyDeviceCode();
      })
    }
    .padding({
      left: 18,
      right: 18,
      top: 18,
      bottom: 18
    })
    .width('100%')
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ResultPanel() {
    Column({ space: 12 }) {
      Text('核验结果')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column({ space: 14 }) {
        Row({ space: 12 }) {
          SymbolGlyph(this.getResultIcon())
            .fontSize(28)
            .fontColor([this.getResultTone()])

          Column({ space: 4 }) {
            Text(this.result!.available ? '设备编号可用' : '设备编号不可用')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TextPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.getResultReason())
              .fontSize(13)
              .fontColor(AppColors.TextSecondary)
              .lineHeight(18)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
        }
        .width('100%')

        Divider()
          .height(1)
          .backgroundColor(AppColors.Divider)

        this.ResultInfoRow('设备编号', DeviceService.normalizeDeviceCode(this.deviceCode), AppColors.TextSecondary)
        this.ResultInfoRow('可用状态', this.result!.available ? '可用' : '不可用', this.getResultTone())
      }
      .width('100%')
      .padding({
        left: 18,
        right: 18,
        top: 18,
        bottom: 18
      })
      .backgroundColor(AppColors.SurfaceRaised)
      .borderRadius(AppRadii.Large)
      .border({
        width: 1,
        color: AppColors.Divider
      })
      .alignItems(HorizontalAlign.Start)

      if (this.result!.available) {
        this.ActionButton('继续添加档案', $r('sys.symbol.plus_circle'), () => {
          this.navigateToCreate();
        }, true)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      InlineMessageSurface({
        message: this.message,
        tone: AppColors.Danger
      })
    }
  }

  @Builder
  ResultInfoRow(label: string, value: string, tone: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppColors.TextSecondary)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .layoutWeight(1)

      Text(value.length > 0 ? value : '-')
        .fontSize(15)
        .fontColor(tone)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('56%')
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  VerifySubmitButton(action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle'))
          .fontSize(20)
          .fontColor([AppColors.OnPrimary])

        Text(this.verifying ? '核验中' : '核验')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.OnPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .width('100%')
    .backgroundColor(this.verifying ? AppColors.Disabled : AppColors.Primary)
    .enabled(!this.verifying)
    .onClick(() => {
      action();
    })
  }

  @Builder
  ActionButton(label: string, icon: Resource, action: () => void, enabled: boolean) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([AppColors.OnPrimary])

        Text(label)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.OnPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .width('100%')
    .backgroundColor(enabled ? AppColors.Primary : AppColors.Disabled)
    .enabled(enabled)
    .onClick(() => {
      action();
    })
  }

  async verifyDeviceCode(): Promise<void> {
    if (this.verifying) {
      return;
    }

    this.message = '';
    this.result = undefined;
    const validation = DeviceService.validateDeviceCodeQuery({
      deviceCode: this.deviceCode
    });
    if (!validation.valid) {
      this.message = validation.message;
      return;
    }

    const deviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    this.deviceCode = deviceCode;
    if (!ApiClient.isConfigured()) {
      this.message = '核验功能暂不可用，请稍后重试';
      return;
    }

    this.verifying = true;
    try {
      const code = encodeURIComponent(deviceCode);
      const response = await ApiClient.request<CodeAvailabilityResult>(
        `/api/v1/device-codes/${code}/availability`, 'GET', true);

      if (!response.success) {
        const error = response.error;
        this.message = this.normalizeVerifyErrorMessage(error === undefined ? '' : `${error.code}`);
        return;
      }

      if (response.data === undefined) {
        this.message = '核验功能暂不可用，请稍后重试';
        return;
      }

      this.result = response.data;
      this.message = '';
    } finally {
      this.verifying = false;
    }
  }

  navigateToCreate(): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/ArchiveCenter/DeviceArchiveCreate',
        params: {
          deviceCode: DeviceService.normalizeDeviceCode(this.deviceCode)
        }
      });
    } catch (err) {
      this.message = '添加设备档案页面不可用';
    }
  }

  normalizeVerifyErrorMessage(errorCode: string): string {
    if (errorCode === 'DEVICE_CODE_INVALID' || errorCode === ApiErrorCode.BadRequest ||
      errorCode === ApiErrorCode.ValidationFailed) {
      return '设备编号无效，请重新输入';
    }

    return '核验功能暂不可用，请稍后重试';
  }

  getResultIcon(): Resource {
    if (this.result !== undefined && this.result.available) {
      return $r('sys.symbol.checkmark_circle');
    }

    return $r('sys.symbol.exclamationmark_circle');
  }

  getResultTone(): string {
    if (this.result !== undefined && this.result.available) {
      return AppColors.Success;
    }

    return AppColors.Danger;
  }

  getResultReason(): string {
    if (this.result !== undefined && this.result.reason !== undefined && this.result.reason.length > 0) {
      return this.result.reason;
    }

    if (this.result !== undefined && this.result.available) {
      return '设备编号可用于添加档案';
    }

    return '设备编号暂不可用于添加档案';
  }

  backToArchiveCenter(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/ArchiveCenter/ArchiveCenter' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}


