import { common } from '@kit.AbilityKit';
import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { DeviceStatus, DeviceSummary } from '../../models/archive/DeviceModels';
import { ApiErrorCode } from '../../models/common/ApiModels';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { DeviceArchiveDeleteGuardService } from '../../services/archive/DeviceArchiveDeleteGuardService';
import { ApiClient } from '../../services/common/ApiClient';
import { DeviceArchiveExportService } from '../../services/archive/DeviceArchiveExportService';
import {
  DeviceQrCodeExportResult,
  DeviceQrCodeExportService
} from '../../services/archive/DeviceQrCodeExportService';
import { DeviceService } from '../../services/archive/DeviceService';
import { DeviceArchiveFlowStore } from '../../stores/DeviceArchiveFlowStore';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';

const ARCHIVE_DETAIL_EXPORT_BODY_ID = 'rdvp_archive_detail_export_body';
const EXPORT_MODE_ARCHIVE_DETAIL = 'ARCHIVE_DETAIL';
const EXPORT_MODE_QR_CODE = 'QR_CODE';

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
  @State exportMenuVisible: boolean = false;
  @State exportVisible: boolean = false;
  @State exportMode: string = EXPORT_MODE_ARCHIVE_DETAIL;
  @State exportPassword: string = '';
  @State exportCaptcha: string = '';
  @State exportCaptchaCode: string = DeviceArchiveDeleteGuardService.createCaptcha();
  @State exportMessage: string = '';
  @State exportMessageTone: string = AppColors.Danger;
  @State exporting: boolean = false;
  @State qrExportResult: DeviceQrCodeExportResult | undefined = undefined;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveQuery)) {
      return;
    }

    this.loadArchiveContext();
  }

  onPageShow(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveQuery)) {
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
    this.canChangeArchive = SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveUpdateRequestSubmit) &&
      !DeviceService.isArchiveRequestLocked(device);
    this.canDeleteArchive = SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveDeleteRequestSubmit) &&
      !DeviceService.isArchiveRequestLocked(device) &&
      !DeviceArchiveDeleteGuardService.isDeleteLocked(device.deviceCode);
    this.canExportQrCode = SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveQrCodeExport);
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
              this.ArchiveExportBody()
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

      if (this.exportMenuVisible) {
        this.ExportMenuOverlay()
      }

      if (this.exportVisible) {
        this.ExportOverlay()
      }
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    if (this.exportMenuVisible) {
      this.exportMenuVisible = false;
      return true;
    }

    if (this.exportVisible) {
      this.closeExportDialog();
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

      if (this.hasDevice) {
        this.ExportButton()
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
  ArchiveExportBody() {
    Column({ space: 18 }) {
      this.ArchivePanel()
      this.StatusPanel()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .id(ARCHIVE_DETAIL_EXPORT_BODY_ID)
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
      .borderRadius(AppRadii.Large)
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
          value: DeviceService.formatArchiveRequestLockReason(this.device),
          tone: DeviceService.isArchiveRequestLocked(this.device) ? AppColors.Danger : AppColors.Success,
          valueMaxLines: 2,
          verticalPadding: 12
        })
      }
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .borderRadius(AppRadii.Large)
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
    .borderRadius(AppRadii.Large)
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
    .borderRadius(AppRadii.Large)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ExportButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Image($r('sys.media.ohos_ic_public_share'))
        .width(24)
        .height(24)
        .fillColor(AppColors.TextPrimary)
    }
    .width(54)
    .height(54)
    .backgroundColor(AppColors.Surface)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .onClick(() => {
      this.openExportMenu();
    })
  }

  @Builder
  ExportMenuOverlay() {
    Column() {
      Column({ space: 10 }) {
        Row() {
          Text('导出')
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
            this.exportMenuVisible = false;
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        this.ExportMenuItem('导出档案详情', $r('sys.symbol.text_clipboard'), () => {
          this.exportMenuVisible = false;
          this.openExportDialog(EXPORT_MODE_ARCHIVE_DETAIL);
        })

        if (this.canExportQrCode) {
          this.ExportMenuItem('导出二维码', $r('sys.symbol.qrcode'), () => {
            this.exportMenuVisible = false;
            this.openExportDialog(EXPORT_MODE_QR_CODE);
          })
        }
      }
      .width('88%')
      .padding({
        left: 18,
        right: 18,
        top: 18,
        bottom: 18
      })
      .backgroundColor(AppColors.Surface)
      .borderRadius(AppRadii.Large)
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Scrim)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ExportMenuItem(label: string, icon: Resource, action: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 12 }) {
        Column() {
          SymbolGlyph(icon)
            .fontSize(22)
            .fontColor([AppColors.Primary])
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(AppColors.PrimarySurface)
        .borderRadius(AppRadii.Medium)

        Text(label)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .layoutWeight(1)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .fontColor([AppColors.TextTertiary])
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(60)
    .padding({ left: 12, right: 12 })
    .backgroundColor(AppColors.FieldBackground)
    .borderRadius(AppRadii.Medium)
    .onClick(() => {
      action();
    })
  }

  @Builder
  ExportOverlay() {
    Column() {
      Column({ space: 16 }) {
        Row() {
          Text(this.getExportDialogTitle())
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
            this.closeExportDialog();
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        this.ExportTargetCard()
        this.ExportPasswordField()
        this.ExportCaptchaField()

        Column({ space: 10 }) {
          this.ExportMessageText()

          Row({ space: 10 }) {
            Column() {
              this.ExportSecondaryButton('取消', () => {
                this.closeExportDialog();
              })
            }
            .layoutWeight(1)

            Column() {
              this.ExportPrimaryButton(this.exporting ? '导出中' : '导出', () => {
                this.confirmAndExport();
              })
            }
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
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
      .borderRadius(AppRadii.Hero)
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Scrim)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ExportTargetCard() {
    if (this.exportMode === EXPORT_MODE_QR_CODE) {
      this.QrExportPreview()
    } else {
      Column({ space: 10 }) {
        Row({ space: 12 }) {
          Column() {
            SymbolGlyph($r('sys.symbol.text_clipboard'))
              .fontSize(26)
              .fontColor([AppColors.Primary])
          }
          .width(48)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(AppColors.PrimarySurface)
          .borderRadius(AppRadii.Medium)

          Column({ space: 4 }) {
            Text('导出档案详情')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TextPrimary)
              .maxLines(1)

            Text(this.device.deviceCode)
              .fontSize(14)
              .fontColor(AppColors.TextSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(AppColors.FieldBackground)
      .borderRadius(AppRadii.Medium)
      .border({ width: 1, color: AppColors.Border })
      .alignItems(HorizontalAlign.Start)
    }
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
      .borderRadius(AppRadii.Medium)
      .border({ width: 1, color: AppColors.Border })
    }
    .width('100%')
  }

  @Builder
  ExportPasswordField() {
    Column({ space: 8 }) {
      this.ExportFieldTitle('当前账号密码')

      TextInput({
        placeholder: '输入当前账号密码',
        text: this.exportPassword
      })
        .type(InputType.Password)
        .height(54)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(AppRadii.Medium)
        .padding({ left: 16, right: 16 })
        .border({ width: 1, color: AppColors.Border })
        .enabled(!this.exporting)
        .onChange((value: string) => {
          this.exportPassword = value;
          this.clearExportMessageOnInput();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ExportCaptchaField() {
    Column({ space: 8 }) {
      this.ExportFieldTitle('验证码')

      Row({ space: 10 }) {
        TextInput({
          placeholder: '输入验证码',
          text: this.exportCaptcha
        })
          .height(54)
          .fontSize(16)
          .backgroundColor(AppColors.FieldBackground)
          .borderRadius(AppRadii.Medium)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: AppColors.Border })
          .layoutWeight(1)
          .enabled(!this.exporting)
          .onChange((value: string) => {
            this.exportCaptcha = value;
            this.clearExportMessageOnInput();
          })

        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Row({ space: 6 }) {
            Text(this.exportCaptchaCode)
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
        .enabled(!this.exporting)
        .onClick(() => {
          this.refreshExportCaptcha();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ExportMessageText() {
    InlineMessageSurface({
      message: this.exportMessage,
      tone: this.exportMessageTone
    })
  }

  @Builder
  ExportFieldTitle(title: string) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColors.TextPrimary)
      .maxLines(1)
  }

  @Builder
  ExportPrimaryButton(label: string, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: !this.exporting && !this.isExportLocked() }) {
      Text(label)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.OnPrimary)
        .maxLines(1)
    }
    .height(52)
    .width('100%')
    .backgroundColor(this.exporting || this.isExportLocked() ? AppColors.Disabled : AppColors.Primary)
    .enabled(!this.exporting && !this.isExportLocked())
    .onClick(() => {
      action();
    })
  }

  @Builder
  ExportSecondaryButton(label: string, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: !this.exporting }) {
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
    .enabled(!this.exporting)
    .onClick(() => {
      action();
    })
  }

  @Builder
  DetailMessageText() {
    InlineMessageSurface({
      message: this.detailMessage,
      tone: this.detailMessageTone
    })
  }

  @Builder
  ChangeActionMessageText() {
    InlineMessageSurface({
      message: this.changeActionMessage,
      tone: this.changeActionMessageTone
    })
  }

  @Builder
  DeleteActionMessageText() {
    InlineMessageSurface({
      message: this.deleteActionMessage,
      tone: this.deleteActionMessageTone
    })
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
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveUpdateRequestSubmit);
  }

  canViewDeleteArchiveAction(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveDeleteRequestSubmit);
  }

  openExportMenu(): void {
    if (!this.hasDevice) {
      return;
    }

    this.exportMenuVisible = true;
  }

  openExportDialog(mode: string): void {
    if (mode === EXPORT_MODE_QR_CODE && !SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveQrCodeExport)) {
      this.detailMessage = '当前账号无权导出设备二维码';
      this.detailMessageTone = AppColors.Danger;
      return;
    }

    if (ApiClient.getBaseUrl().length === 0) {
      this.detailMessage = '导出功能暂不可用，请稍后重试';
      this.detailMessageTone = AppColors.Danger;
      return;
    }

    if (mode === EXPORT_MODE_QR_CODE && DeviceArchiveDeleteGuardService.isQrExportLocked(this.device.deviceCode)) {
      this.detailMessage = DeviceArchiveDeleteGuardService.getQrExportLockMessage(this.device.deviceCode);
      this.detailMessageTone = AppColors.Danger;
      return;
    }

    this.exportMode = mode;
    this.exportVisible = true;
    this.exportPassword = '';
    this.exportCaptcha = '';
    this.exportCaptchaCode = DeviceArchiveDeleteGuardService.createCaptcha();
    this.exportMessage = '';
    this.exportMessageTone = AppColors.Danger;
    this.qrExportResult = undefined;
  }

  closeExportDialog(): void {
    if (this.exporting) {
      return;
    }

    this.exportVisible = false;
    this.exportPassword = '';
    this.exportCaptcha = '';
    this.exportMessage = '';
    this.qrExportResult = undefined;
  }

  refreshExportCaptcha(): void {
    this.exportCaptchaCode = DeviceArchiveDeleteGuardService.createCaptcha();
    this.exportCaptcha = '';
    this.exportMessage = '';
    this.qrExportResult = undefined;
  }

  clearExportMessageOnInput(): void {
    this.exportMessage = '';
    this.qrExportResult = undefined;
  }

  async confirmAndExport(): Promise<void> {
    if (this.exporting) {
      return;
    }

    if (!this.validateExportForm()) {
      return;
    }

    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.exportMessage = '导出功能暂不可用，请稍后重试';
      this.exportMessageTone = AppColors.Danger;
      return;
    }

    this.exporting = true;
    if (this.exportMode === EXPORT_MODE_QR_CODE) {
      await this.confirmAndExportQrCode(context);
      return;
    }

    await this.confirmAndExportArchiveDetail(context);
  }

  validateExportForm(): boolean {
    if (this.exportMode === EXPORT_MODE_QR_CODE && DeviceArchiveDeleteGuardService.isQrExportLocked(this.device.deviceCode)) {
      this.exportMessage = DeviceArchiveDeleteGuardService.getQrExportLockMessage(this.device.deviceCode);
      this.exportMessageTone = AppColors.Danger;
      return false;
    }

    if (this.exportCaptcha.trim().length === 0) {
      this.exportMessage = '请输入验证码';
      this.exportMessageTone = AppColors.Danger;
      return false;
    }

    if (this.exportCaptcha.trim() !== this.exportCaptchaCode.trim()) {
      this.exportMessage = '验证码错误，请重新输入';
      this.exportMessageTone = AppColors.Danger;
      this.exportCaptcha = '';
      this.exportCaptchaCode = DeviceArchiveDeleteGuardService.createCaptcha();
      this.qrExportResult = undefined;
      return false;
    }

    return true;
  }

  async confirmAndExportArchiveDetail(context: common.Context): Promise<void> {
    const verifyResponse = await DeviceArchiveExportService.verifyArchiveDetailExportRemoteFirst({
      deviceId: this.device.id,
      password: this.exportPassword
    });
    if (!verifyResponse.success || verifyResponse.data === undefined || !verifyResponse.data.verified) {
      this.exportMessage = this.mapExportErrorMessage(verifyResponse.error === undefined ? '' : `${verifyResponse.error.code}`,
        verifyResponse.error === undefined ? '' : verifyResponse.error.message);
      this.exportMessageTone = AppColors.Danger;
      this.exporting = false;
      this.exportCaptcha = '';
      this.exportCaptchaCode = DeviceArchiveDeleteGuardService.createCaptcha();
      this.qrExportResult = undefined;
      return;
    }

    const saveResponse = await DeviceArchiveExportService.saveArchiveSnapshotToGallery(
      context,
      this.getUIContext(),
      ARCHIVE_DETAIL_EXPORT_BODY_ID,
      verifyResponse.data.deviceCode
    );
    this.exporting = false;
    if (!saveResponse.success) {
      const error = saveResponse.error;
      this.exportMessage = error ? error.message : '档案详情导出失败';
      this.exportMessageTone = AppColors.Warning;
      return;
    }

    this.exportMessage = `档案详情已导出到相册：${saveResponse.data}`;
    this.exportMessageTone = AppColors.Success;
  }

  async confirmAndExportQrCode(context: common.Context): Promise<void> {
    const exportResponse = await DeviceQrCodeExportService.exportQrCodeRemoteFirst({
      deviceId: this.device.id,
      password: this.exportPassword
    });
    if (!exportResponse.success || exportResponse.data === undefined) {
      const error = exportResponse.error;
      if (this.isQrExportPasswordError(error === undefined ? '' : `${error.code}`)) {
        const guardResult = DeviceArchiveDeleteGuardService.registerQrExportPasswordFailure(this.device.deviceCode);
        this.exportMessage = guardResult.message;
      } else {
        this.exportMessage = this.mapExportErrorMessage(error === undefined ? '' : `${error.code}`,
          error === undefined ? '' : error.message);
      }
      this.exportMessageTone = AppColors.Danger;
      this.exporting = false;
      this.exportCaptcha = '';
      this.exportCaptchaCode = DeviceArchiveDeleteGuardService.createCaptcha();
      this.qrExportResult = undefined;
      return;
    }

    this.qrExportResult = exportResponse.data;
    DeviceArchiveDeleteGuardService.clearQrExportLock(this.device.deviceCode);
    const saveResponse = await DeviceQrCodeExportService.saveImageToGallery(context, exportResponse.data);
    this.exporting = false;
    if (!saveResponse.success) {
      const error = saveResponse.error;
      this.exportMessage = error ? error.message : '二维码保存失败';
      this.exportMessageTone = AppColors.Warning;
      return;
    }

    this.exportMessage = `二维码已导出到相册：${saveResponse.data}`;
    this.exportMessageTone = AppColors.Success;
  }

  getQrExportImageDataUri(): string {
    if (this.qrExportResult === undefined) {
      return '';
    }

    return DeviceQrCodeExportService.getImageDataUri(this.qrExportResult);
  }

  isExportLocked(): boolean {
    return this.exportMode === EXPORT_MODE_QR_CODE && DeviceArchiveDeleteGuardService.isQrExportLocked(this.device.deviceCode);
  }

  isQrExportPasswordError(errorCode: string): boolean {
    return errorCode === 'INVALID_CREDENTIALS' || errorCode === 'LOGIN_FAILED';
  }

  mapExportErrorMessage(errorCode: string, fallbackMessage: string): string {
    if (errorCode === 'INVALID_CREDENTIALS' || errorCode === 'LOGIN_FAILED') {
      return '当前账号密码错误，请重新输入';
    }

    if (errorCode === ApiErrorCode.ServiceUnavailable || errorCode === 'SERVICE_UNAVAILABLE') {
      return '导出功能暂不可用，请稍后重试';
    }

    if (fallbackMessage.length > 0) {
      return fallbackMessage;
    }

    return '导出功能暂不可用，请稍后重试';
  }

  getExportDialogTitle(): string {
    return this.exportMode === EXPORT_MODE_QR_CODE ? '导出二维码' : '导出档案详情';
  }

  openChangePage(): void {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveUpdateRequestSubmit)) {
      this.changeActionMessage = '当前账号无权申请修改设备档案';
      this.changeActionMessageTone = AppColors.Danger;
      return;
    }

    if (DeviceService.isArchiveRequestLocked(this.device)) {
      this.changeActionMessage = DeviceService.formatArchiveRequestLockReason(this.device);
      this.changeActionMessageTone = AppColors.Danger;
      return;
    }

    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/DeviceArchiveUpdate' });
    } catch (err) {
      this.changeActionMessage = '修改设备档案不可用';
      this.changeActionMessageTone = AppColors.Danger;
    }
  }

  openDeletePage(): void {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveDeleteRequestSubmit)) {
      this.deleteActionMessage = '当前账号无权申请删除设备档案';
      this.deleteActionMessageTone = AppColors.Danger;
      return;
    }

    if (DeviceArchiveDeleteGuardService.isDeleteLocked(this.device.deviceCode)) {
      this.deleteActionMessage = DeviceArchiveDeleteGuardService.getDeleteLockMessage(this.device.deviceCode);
      this.deleteActionMessageTone = AppColors.Danger;
      return;
    }

    if (DeviceService.isArchiveRequestLocked(this.device)) {
      this.deleteActionMessage = DeviceService.formatArchiveRequestLockReason(this.device);
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


