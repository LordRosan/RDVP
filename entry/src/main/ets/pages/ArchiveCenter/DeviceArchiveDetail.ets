import { AppColors } from '../../styles/AppTheme';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { DeviceStatus, DeviceSummary } from '../../models/DeviceModels';
import { PermissionCode } from '../../models/PermissionModels';
import { DeviceArchiveDeleteGuardService } from '../../services/DeviceArchiveDeleteGuardService';
import { ApiClient } from '../../services/ApiClient';
import {
  DeviceQrCodeExportResult,
  DeviceQrCodeExportService
} from '../../services/DeviceQrCodeExportService';
import { DeviceService } from '../../services/DeviceService';
import { DeviceArchiveFlowStore } from '../../stores/DeviceArchiveFlowStore';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';

@Entry
@Component
struct DeviceArchiveDetail {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State device: DeviceSummary = {
    id: '',
    deviceCode: '-',
    name: '-',
    model: '-',
    manufacturer: '-',
    location: {
      address: '-'
    },
    status: DeviceStatus.PendingVerification
  };
  @State hasDevice: boolean = false;
  @State detailMessage: string = '';
  @State detailMessageTone: string = AppColors.Danger;
  @State changeActionMessage: string = '';
  @State changeActionMessageTone: string = AppColors.Danger;
  @State deleteActionMessage: string = '';
  @State deleteActionMessageTone: string = AppColors.Danger;
  @State canChangeArchive: boolean = false;
  @State canDeleteArchive: boolean = false;
  @State canExportQrCode: boolean = false;
  @State qrExportVisible: boolean = false;
  @State qrExportPassword: string = '';
  @State qrExportCaptcha: string = '';
  @State qrExportCaptchaCode: string = DeviceArchiveDeleteGuardService.createCaptcha();
  @State qrExportMessage: string = '';
  @State qrExportMessageTone: string = AppColors.Danger;
  @State qrExporting: boolean = false;
  @State qrExportResult: DeviceQrCodeExportResult | undefined = undefined;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveDeviceRead)) {
      return;
    }

    this.loadArchiveContext();
  }

  onPageShow(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveDeviceRead)) {
      return;
    }

    this.loadArchiveContext();
  }

  loadArchiveContext(): void {
    const device = DeviceArchiveFlowStore.getCurrentDevice();
    if (device === undefined) {
      const lastCode = DeviceArchiveFlowStore.getLastDeviceCode();
      if (lastCode.length > 0) {
        this.reloadDeviceByCode(lastCode);
        return;
      }

      this.hasDevice = false;
      this.canChangeArchive = false;
      this.canDeleteArchive = false;
      this.canExportQrCode = false;
      this.detailMessage = '未获取设备档案，请重新查询';
      this.detailMessageTone = AppColors.Danger;
      this.changeActionMessage = '';
      this.deleteActionMessage = '';
      return;
    }

    this.device = device;
    this.hasDevice = true;
    this.canChangeArchive = SessionStore.hasPermission(PermissionCode.ArchiveDeviceChangeRequestCreate) &&
      !DeviceService.isArchiveChangeLocked(device);
    this.canDeleteArchive = SessionStore.hasPermission(PermissionCode.ArchiveDeviceDelete) &&
      !DeviceService.isArchiveChangeLocked(device) &&
      !DeviceArchiveDeleteGuardService.isDeleteLocked(device.deviceCode);
    this.canExportQrCode = SessionStore.hasPermission(PermissionCode.ArchiveQrCodeExport);
    this.detailMessage = '';
    this.detailMessageTone = AppColors.Danger;
    this.changeActionMessage = '';
    this.changeActionMessageTone = AppColors.Danger;
    if (DeviceArchiveDeleteGuardService.isDeleteLocked(device.deviceCode)) {
      this.deleteActionMessage = DeviceArchiveDeleteGuardService.getDeleteLockMessage(device.deviceCode);
      this.deleteActionMessageTone = AppColors.Danger;
      return;
    }

    this.deleteActionMessage = '';
    this.deleteActionMessageTone = AppColors.Danger;
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          this.PageTitleBar()

          Column({ space: 18 }) {
            this.ModeHeader()
            if (this.hasDevice) {
              this.ArchivePanel()
              this.StatusPanel()
              if (this.shouldShowActionPanel()) {
                this.ActionPanel()
              }
            } else {
              this.EmptyPanel()
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

      if (this.qrExportVisible) {
        this.QrExportOverlay()
      }
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    if (this.qrExportVisible) {
      this.closeQrExportDialog();
      return true;
    }

    this.returnToQuery();
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
      .border({
        width: 1,
        color: AppColors.Divider
      })
      .onClick(() => {
        this.returnToQuery();
      })
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: 24,
      right: 24
    })
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  ModeHeader() {
    Row({ space: 16 }) {
      Text('设备档案详情')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(1)

      if (this.canExportQrCode && this.hasDevice) {
        this.QrExportButton()
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      top: 0,
      bottom: 2
    })
  }

  @Builder
  ArchivePanel() {
    Column({ space: 10 }) {
      Text('档案信息')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({
          label: '设备编号',
          value: this.device.deviceCode,
          tone: AppColors.TextSecondary,
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '设备名称',
          value: this.device.name,
          tone: AppColors.TextSecondary,
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '设备型号',
          value: this.device.model,
          tone: AppColors.TextSecondary,
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '生产厂商',
          value: this.device.manufacturer,
          tone: AppColors.TextSecondary,
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '设备位置',
          value: this.device.location.address,
          tone: AppColors.TextSecondary,
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '最近核验',
          value: DeviceService.formatTimestampForDisplay(this.device.lastVerificationTime),
          tone: AppColors.TextSecondary,
          valueMaxLines: 2,
          verticalPadding: 12
        })
      }
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .borderRadius(24)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  StatusPanel() {
    Column({ space: 10 }) {
      Text('状态信息')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({
          label: '设备状态',
          value: DeviceService.formatDeviceStatus(this.device.status),
          tone: DeviceService.getDeviceStatusTone(this.device.status),
          valueMaxLines: 2,
          verticalPadding: 12
        })
        this.CardDivider()
        StatusInfoRow({
          label: '档案状态',
          value: DeviceService.formatArchiveChangeLockReason(this.device),
          tone: DeviceService.isArchiveChangeLocked(this.device) ? AppColors.Danger : AppColors.Success,
          valueMaxLines: 2,
          verticalPadding: 12
        })
      }
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .borderRadius(24)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  ActionPanel() {
    Column({ space: 12 }) {
      this.DetailMessageText()
      if (this.canViewChangeArchiveAction()) {
        this.ChangeActionMessageText()
        this.ChangeArchiveButton()
      }
      if (this.canViewDeleteArchiveAction()) {
        this.DeleteActionMessageText()
        this.DeleteArchiveButton()
      }
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
  EmptyPanel() {
    Column({ space: 12 }) {
      this.DetailMessageText()
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
  QrExportButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.qrcode'))
        .fontSize(30)
        .fontColor([AppColors.TextPrimary])
    }
    .width(54)
    .height(54)
    .backgroundColor(AppColors.Surface)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .onClick(() => {
      this.openQrExportDialog();
    })
  }

  @Builder
  QrExportOverlay() {
    Column() {
      Column({ space: 16 }) {
        Row() {
          Text('导出设备二维码')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .layoutWeight(1)
            .maxLines(1)

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(18)
              .fontColor([AppColors.TextPrimary])
          }
          .width(40)
          .height(40)
          .backgroundColor(AppColors.PageBackground)
          .onClick(() => {
            this.closeQrExportDialog();
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        this.QrExportPreview()
        this.QrExportPasswordField()
        this.QrExportCaptchaField()

        Row({ space: 10 }) {
          Column() {
            this.QrExportSecondaryButton('取消', () => {
              this.closeQrExportDialog();
            })
          }
          .layoutWeight(1)

          Column({ space: 8 }) {
            this.QrExportMessageText()
            this.QrExportPrimaryButton(this.qrExporting ? '导出中' : '导出', () => {
              this.confirmAndExportQrCode();
            })
          }
          .layoutWeight(1)
        }
        .width('100%')
      }
      .width('88%')
      .padding({
        left: 22,
        right: 22,
        top: 22,
        bottom: 22
      })
      .backgroundColor(AppColors.Surface)
      .borderRadius(28)
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Scrim)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  QrExportPreview() {
    Column({ space: 8 }) {
      Stack() {
        if (this.getQrExportImageDataUri().length > 0) {
          Image(this.getQrExportImageDataUri())
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        } else {
          Column({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.qrcode'))
              .fontSize(54)
              .fontColor([AppColors.TextSecondary])

            Text('完成身份复核后生成二维码')
              .fontSize(13)
              .fontColor(AppColors.TextSecondary)
              .maxLines(2)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      }
      .width('100%')
      .aspectRatio(1)
      .padding(16)
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(18)
      .border({ width: 1, color: AppColors.Border })

      Text(`内容摘要：${this.getQrExportDigestText()}`)
        .fontSize(12)
        .fontColor(AppColors.TextSecondary)
        .width('100%')
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }

  @Builder
  QrExportPasswordField() {
    Column({ space: 8 }) {
      this.QrExportFieldTitle('当前账号密码')

      TextInput({
        placeholder: '输入当前账号密码',
        text: this.qrExportPassword
      })
        .type(InputType.Password)
        .height(54)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.qrExporting)
        .onChange((value: string) => {
          this.qrExportPassword = value;
          this.clearQrExportMessageOnInput();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  QrExportCaptchaField() {
    Column({ space: 8 }) {
      this.QrExportFieldTitle('验证码')

      Row({ space: 10 }) {
        TextInput({
          placeholder: '输入验证码',
          text: this.qrExportCaptcha
        })
          .height(54)
          .fontSize(16)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
          .layoutWeight(1)
          .enabled(!this.qrExporting)
          .onChange((value: string) => {
            this.qrExportCaptcha = value;
            this.clearQrExportMessageOnInput();
          })

        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Row({ space: 6 }) {
            Text(this.qrExportCaptchaCode)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TextPrimary)
              .maxLines(1)

            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(16)
              .fontColor([AppColors.TextPrimary])
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .width('100%')
        }
        .width(116)
        .height(54)
        .backgroundColor(AppColors.PageBackground)
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.qrExporting)
        .onClick(() => {
          this.refreshQrExportCaptcha();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  QrExportMessageText() {
    if (this.qrExportMessage.length > 0) {
      Text(this.qrExportMessage)
        .fontSize(13)
        .fontColor(this.qrExportMessageTone)
        .lineHeight(18)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  QrExportFieldTitle(title: string) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.TextPrimary)
      .maxLines(1)
  }

  @Builder
  QrExportPrimaryButton(label: string, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: !this.qrExporting && !this.isQrExportLocked() }) {
      Text(label)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.OnPrimary)
        .maxLines(1)
    }
    .height(52)
    .width('100%')
    .backgroundColor(this.qrExporting || this.isQrExportLocked() ? AppColors.Disabled : AppColors.Primary)
    .enabled(!this.qrExporting && !this.isQrExportLocked())
    .onClick(() => {
      action();
    })
  }

  @Builder
  QrExportSecondaryButton(label: string, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: !this.qrExporting }) {
      Text(label)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
    }
    .height(52)
    .width('100%')
    .backgroundColor(AppColors.FieldBackground)
    .border({ width: 1, color: AppColors.Border })
    .enabled(!this.qrExporting)
    .onClick(() => {
      action();
    })
  }

  @Builder
  DetailMessageText() {
    if (this.detailMessage.length > 0) {
      Text(this.detailMessage)
        .fontSize(13)
        .fontColor(this.detailMessageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ChangeActionMessageText() {
    if (this.changeActionMessage.length > 0) {
      Text(this.changeActionMessage)
        .fontSize(13)
        .fontColor(this.changeActionMessageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  DeleteActionMessageText() {
    if (this.deleteActionMessage.length > 0) {
      Text(this.deleteActionMessage)
        .fontSize(13)
        .fontColor(this.deleteActionMessageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ChangeArchiveButton() {
    if (this.canViewChangeArchiveAction()) {
      Button({ type: ButtonType.Capsule, stateEffect: this.canChangeArchive }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.text_clipboard'))
            .fontSize(20)
            .fontColor([AppColors.OnPrimary])

          Text('修改设备档案')
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
      .backgroundColor(this.canChangeArchive ? AppColors.Primary : AppColors.Disabled)
      .enabled(this.canChangeArchive)
      .onClick(() => {
        this.openChangePage();
      })
    }
  }

  @Builder
  DeleteArchiveButton() {
    if (this.canViewDeleteArchiveAction()) {
      Button({ type: ButtonType.Capsule, stateEffect: this.canDeleteArchive }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(20)
            .fontColor([AppColors.OnPrimary])

          Text('删除设备档案')
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
      .backgroundColor(this.canDeleteArchive ? AppColors.Danger : AppColors.Disabled)
      .enabled(this.canDeleteArchive)
      .onClick(() => {
        this.openDeletePage();
      })
    }
  }

  @Builder
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
      .margin({
        left: 18,
        right: 18
      })
  }

  shouldShowActionPanel(): boolean {
    return this.detailMessage.length > 0 || this.changeActionMessage.length > 0 ||
      this.deleteActionMessage.length > 0 || this.canViewChangeArchiveAction() || this.canViewDeleteArchiveAction();
  }

  canViewChangeArchiveAction(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveDeviceChangeRequestCreate);
  }

  canViewDeleteArchiveAction(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveDeviceDelete);
  }

  openQrExportDialog(): void {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveQrCodeExport)) {
      this.detailMessage = '当前账号无权导出设备二维码';
      this.detailMessageTone = AppColors.Danger;
      return;
    }

    if (ApiClient.getBaseUrl().length === 0) {
      this.detailMessage = '后端服务地址未配置，无法导出设备二维码';
      this.detailMessageTone = AppColors.Danger;
      return;
    }

    if (DeviceArchiveDeleteGuardService.isQrExportLocked(this.device.deviceCode)) {
      this.detailMessage = DeviceArchiveDeleteGuardService.getQrExportLockMessage(this.device.deviceCode);
      this.detailMessageTone = AppColors.Danger;
      return;
    }

    this.qrExportVisible = true;
    this.qrExportPassword = '';
    this.qrExportCaptcha = '';
    this.qrExportCaptchaCode = DeviceArchiveDeleteGuardService.createCaptcha();
    this.qrExportMessage = '';
    this.qrExportMessageTone = AppColors.Danger;
    this.qrExportResult = undefined;
  }

  closeQrExportDialog(): void {
    if (this.qrExporting) {
      return;
    }

    this.qrExportVisible = false;
    this.qrExportPassword = '';
    this.qrExportCaptcha = '';
    this.qrExportMessage = '';
    this.qrExportResult = undefined;
  }

  refreshQrExportCaptcha(): void {
    this.qrExportCaptchaCode = DeviceArchiveDeleteGuardService.createCaptcha();
    this.qrExportCaptcha = '';
    this.qrExportMessage = '';
    this.qrExportResult = undefined;
  }

  clearQrExportMessageOnInput(): void {
    this.qrExportMessage = '';
    this.qrExportResult = undefined;
  }

  async confirmAndExportQrCode(): Promise<void> {
    if (this.qrExporting) {
      return;
    }

    if (DeviceArchiveDeleteGuardService.isQrExportLocked(this.device.deviceCode)) {
      this.qrExportMessage = DeviceArchiveDeleteGuardService.getQrExportLockMessage(this.device.deviceCode);
      this.qrExportMessageTone = AppColors.Danger;
      return;
    }

    if (this.qrExportCaptcha.trim().length === 0) {
      this.qrExportMessage = '请输入验证码';
      this.qrExportMessageTone = AppColors.Danger;
      return;
    }

    if (this.qrExportCaptcha.trim() !== this.qrExportCaptchaCode.trim()) {
      this.qrExportMessage = '验证码错误，请重新输入';
      this.qrExportMessageTone = AppColors.Danger;
      this.qrExportCaptcha = '';
      this.qrExportCaptchaCode = DeviceArchiveDeleteGuardService.createCaptcha();
      this.qrExportResult = undefined;
      return;
    }

    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.qrExportMessage = '无法获取页面上下文';
      this.qrExportMessageTone = AppColors.Danger;
      return;
    }

    this.qrExporting = true;
    const exportResponse = await DeviceQrCodeExportService.exportQrCodeRemoteFirst({
      deviceId: this.device.id,
      password: this.qrExportPassword
    });
    if (!exportResponse.success || exportResponse.data === undefined) {
      const error = exportResponse.error;
      if (this.isQrExportPasswordError(error === undefined ? '' : `${error.code}`)) {
        const guardResult = DeviceArchiveDeleteGuardService.registerQrExportPasswordFailure(this.device.deviceCode);
        this.qrExportMessage = guardResult.message;
      } else {
        this.qrExportMessage = error ? error.message : '二维码导出失败';
      }
      this.qrExportMessageTone = AppColors.Danger;
      this.qrExporting = false;
      this.qrExportCaptcha = '';
      this.qrExportCaptchaCode = DeviceArchiveDeleteGuardService.createCaptcha();
      this.qrExportResult = undefined;
      return;
    }

    this.qrExportResult = exportResponse.data;
    DeviceArchiveDeleteGuardService.clearQrExportLock(this.device.deviceCode);
    const saveResponse = await DeviceQrCodeExportService.saveImageToGallery(context, exportResponse.data);
    this.qrExporting = false;
    if (!saveResponse.success) {
      const error = saveResponse.error;
      this.qrExportMessage = error ? error.message : '二维码保存失败';
      this.qrExportMessageTone = AppColors.Warning;
      return;
    }

    this.qrExportMessage = `二维码已导出到相册：${saveResponse.data}`;
    this.qrExportMessageTone = AppColors.Success;
  }

  getQrExportImageDataUri(): string {
    if (this.qrExportResult === undefined) {
      return '';
    }

    return DeviceQrCodeExportService.getImageDataUri(this.qrExportResult);
  }

  getQrExportDigestText(): string {
    if (this.qrExportResult === undefined) {
      return '-';
    }

    return DeviceQrCodeExportService.formatDigest(this.qrExportResult);
  }

  isQrExportLocked(): boolean {
    return DeviceArchiveDeleteGuardService.isQrExportLocked(this.device.deviceCode);
  }

  isQrExportPasswordError(errorCode: string): boolean {
    return errorCode === 'INVALID_CREDENTIALS' || errorCode === 'LOGIN_FAILED';
  }

  openChangePage(): void {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveDeviceChangeRequestCreate)) {
      this.changeActionMessage = '当前账号无权申请修改设备档案';
      this.changeActionMessageTone = AppColors.Danger;
      return;
    }

    if (DeviceService.isArchiveChangeLocked(this.device)) {
      this.changeActionMessage = DeviceService.formatArchiveChangeLockReason(this.device);
      this.changeActionMessageTone = AppColors.Danger;
      return;
    }

    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/DeviceArchiveChange' });
    } catch (err) {
      this.changeActionMessage = '修改设备档案不可用';
      this.changeActionMessageTone = AppColors.Danger;
    }
  }

  openDeletePage(): void {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveDeviceDelete)) {
      this.deleteActionMessage = '当前账号无权申请删除设备档案';
      this.deleteActionMessageTone = AppColors.Danger;
      return;
    }

    if (DeviceArchiveDeleteGuardService.isDeleteLocked(this.device.deviceCode)) {
      this.deleteActionMessage = DeviceArchiveDeleteGuardService.getDeleteLockMessage(this.device.deviceCode);
      this.deleteActionMessageTone = AppColors.Danger;
      return;
    }

    if (DeviceService.isArchiveChangeLocked(this.device)) {
      this.deleteActionMessage = DeviceService.formatArchiveChangeLockReason(this.device);
      this.deleteActionMessageTone = AppColors.Danger;
      return;
    }

    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/DeviceArchiveDelete' });
    } catch (err) {
      this.deleteActionMessage = '删除设备档案不可用';
      this.deleteActionMessageTone = AppColors.Danger;
    }
  }

  returnToQuery(): void {
    try {
      DeviceArchiveFlowStore.clearFlow();
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/ArchiveCenter/DeviceArchiveQuery' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }

  async reloadDeviceByCode(deviceCode: string): Promise<void> {
    this.detailMessage = '正在重新获取设备档案...';
    this.detailMessageTone = AppColors.TextSecondary;
    const response = await DeviceService.queryByCodeRemoteFirst({
      deviceCode
    });
    if (response.success && response.data !== undefined) {
      DeviceArchiveFlowStore.startFlow(response.data);
      this.loadArchiveContext();
    } else {
      this.hasDevice = false;
      this.canChangeArchive = false;
      this.canDeleteArchive = false;
      this.canExportQrCode = false;
      this.detailMessage = '重新获取设备档案失败，请返回查询';
      this.detailMessageTone = AppColors.Danger;
    }
  }
}
