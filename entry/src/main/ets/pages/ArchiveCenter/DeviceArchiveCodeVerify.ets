import { AppColors } from '../../styles/AppTheme';
import { PermissionCode } from '../../models/PermissionModels';
import { ApiClient } from '../../services/ApiClient';
import { DeviceService } from '../../services/DeviceService';
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
  @State messageTone: string = AppColors.TextSecondary;
  @State verifying: boolean = false;
  @State result: CodeAvailabilityResult | undefined = undefined;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveDeviceCreate)) {
      return;
    }
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.VerifyForm()
          if (this.result !== undefined) {
            this.ResultPanel()
          }
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .padding({
          left: 24,
          right: 24,
          top: 0,
          bottom: 28
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
      .backgroundColor(AppColors.Surface)
      .border({ width: 1, color: AppColors.Divider })
      .onClick(() => {
        this.backToArchiveCenter();
      })
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 24, right: 24 })
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  ModeHeader() {
    Text('设备编号核验')
      .fontSize(34)
      .fontWeight(FontWeight.Bold)
      .fontColor(AppColors.TextPrimary)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    .width('100%')
    .alignSelf(ItemAlign.Start)
    .padding({ top: 0, bottom: 2 })
  }

  @Builder
  VerifyForm() {
    Column({ space: 14 }) {
      Text('输入设备编号')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      TextInput({
        placeholder: '例如 RDVP-DEVICE-0100',
        text: this.deviceCode
      })
        .height(56)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: AppColors.Border })
        .onChange((value: string) => {
          this.deviceCode = value;
          this.message = '';
          this.result = undefined;
        })

      this.MessageText()
      this.ActionButton(this.verifying ? '核验中' : '核验', () => {
        this.verifyDeviceCode();
      }, !this.verifying)
    }
    .padding({
      left: 18,
      right: 18,
      top: 18,
      bottom: 18
    })
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ResultPanel() {
    Column({ space: 10 }) {
      Text('核验结果')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column({ space: 16 }) {
        Row() {
          Text('可用状态')
            .fontSize(15)
            .fontColor(AppColors.TextPrimary)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
            .maxLines(1)

          Text(this.result!.available ? '可用' : '不可用')
            .fontSize(15)
            .fontColor(this.result!.available ? AppColors.Success : AppColors.Danger)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
        }
        .width('100%')
        .height(54)
        .padding({ left: 18, right: 18 })

        if (this.result!.reason !== undefined && this.result!.reason.length > 0) {
          Divider()
            .height(1)
            .backgroundColor(AppColors.Divider)
            .margin({ left: 18, right: 18 })

          Row() {
            Text('说明')
              .fontSize(15)
              .fontColor(AppColors.TextPrimary)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
              .maxLines(1)

            Text(this.result!.reason)
              .fontSize(15)
              .fontColor(AppColors.TextSecondary)
              .fontWeight(FontWeight.Medium)
              .textAlign(TextAlign.End)
              .width('58%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ left: 18, right: 18 })
        }
      }
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .borderRadius(24)
      .alignItems(HorizontalAlign.Start)

      if (this.result!.available) {
        this.ActionButton('继续添加档案', () => {
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
      Text(this.message)
        .fontSize(13)
        .fontColor(this.messageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ActionButton(label: string, action: () => void, enabled: boolean) {
    Button({ type: ButtonType.Capsule, stateEffect: enabled }) {
      Text(label)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.OnPrimary)
        .maxLines(1)
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

    const deviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    if (deviceCode.length === 0) {
      this.message = '请输入设备编号';
      this.messageTone = AppColors.Danger;
      return;
    }

    if (!/^RDVP-DEVICE-\d{4}$/.test(deviceCode)) {
      this.message = '设备编号格式应为 RDVP-DEVICE-0001';
      this.messageTone = AppColors.Danger;
      return;
    }

    if (!ApiClient.isConfigured()) {
      this.message = '后端服务地址未配置，无法核验设备编号';
      this.messageTone = AppColors.Danger;
      return;
    }

    this.verifying = true;
    this.result = undefined;
    const code = encodeURIComponent(deviceCode);
    const response = await ApiClient.request<CodeAvailabilityResult>(
      `/api/v1/device-codes/${code}/availability`, 'GET', true);
    this.verifying = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '设备编号核验失败';
      this.messageTone = AppColors.Danger;
      return;
    }

    if (response.data === undefined) {
      this.message = '核验响应无效';
      this.messageTone = AppColors.Danger;
      return;
    }

    this.result = response.data;
    if (this.result!.available) {
      this.message = '';
    } else {
      this.message = this.result!.reason ? this.result!.reason : '设备编号不可用';
      this.messageTone = AppColors.Danger;
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
      this.messageTone = AppColors.Danger;
    }
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
