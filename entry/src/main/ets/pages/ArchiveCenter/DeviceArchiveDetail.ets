import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { DeviceStatus, DeviceSummary } from '../../models/archive/DeviceModels';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { DeviceArchiveDeleteGuardService } from '../../services/archive/DeviceArchiveDeleteGuardService';
import { DeviceService } from '../../services/archive/DeviceService';
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
  @State canExportArchive: boolean = false;
  @State exportActionMessage: string = '';
  @State exportActionMessageTone: string = AppColors.Danger;

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
      this.canExportArchive = false;
      this.detailMessage = '未获取设备档案，请重新查询';
      this.detailMessageTone = AppColors.Danger;
      this.changeActionMessage = '';
      this.deleteActionMessage = '';
      this.exportActionMessage = '';
      return;
    }

    this.device = device;
    this.hasDevice = true;
    this.canChangeArchive = SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveUpdateRequestSubmit) &&
      !DeviceService.isArchiveRequestLocked(device);
    this.canDeleteArchive = SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveDeleteRequestSubmit) &&
      !DeviceService.isArchiveRequestLocked(device) &&
      !DeviceArchiveDeleteGuardService.isDeleteLocked(device.deviceCode);
    this.canExportArchive = SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveExport);
    this.detailMessage = '';
    this.detailMessageTone = AppColors.Danger;
    this.changeActionMessage = '';
    this.changeActionMessageTone = AppColors.Danger;
    this.exportActionMessage = '';
    this.exportActionMessageTone = AppColors.Danger;
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

    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
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
    Column({ space: 5 }) {
      Text('设备档案详情')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '82%' })

      Text('Device Archive Detail')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      top: 12,
      bottom: 6
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
  }

  @Builder
  ArchivePanel() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '档案信息',
        subtitle: ''
      })

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
      .backgroundColor(AppColors.SurfaceRaised)
      .borderRadius(AppRadii.Large)
      .border({
        width: 1,
        color: AppColors.Divider
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  StatusPanel() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '状态信息',
        subtitle: ''
      })

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
      .backgroundColor(AppColors.SurfaceRaised)
      .borderRadius(AppRadii.Large)
      .border({
        width: 1,
        color: AppColors.Divider
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  ActionPanel() {
    Column({ space: 12 }) {
      this.DetailMessageText()
      if (this.canViewExportArchiveAction()) {
        this.ExportActionMessageText()
        this.DetailActionTile('导出设备档案', $r('sys.media.ohos_save_button_line'), AppColors.Primary,
          AppColors.PrimarySurface, this.canExportArchive, () => {
            this.openExportVerifyPage();
          }, true)
      }
      if (this.canViewChangeArchiveAction()) {
        this.ChangeActionMessageText()
        this.DetailActionTile('修改设备档案', $r('sys.symbol.text_clipboard'), AppColors.Primary,
          AppColors.PrimarySurface, this.canChangeArchive, () => {
            this.openChangePage();
          })
      }
      if (this.canViewDeleteArchiveAction()) {
        this.DeleteActionMessageText()
        this.DetailActionTile('删除设备档案', $r('sys.symbol.trash'), AppColors.Danger,
          AppColors.DangerSurface, this.canDeleteArchive, () => {
            this.openDeletePage();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DetailActionTile(
    title: string,
    icon: Resource,
    tone: string,
    surfaceTone: string,
    enabled: boolean,
    action: () => void,
    useImageIcon: boolean = false
  ) {
    Row({ space: 14 }) {
      Stack() {
        if (useImageIcon) {
          Image(icon)
            .width(24)
            .height(24)
            .fillColor(enabled ? tone : AppColors.Disabled)
        } else {
          SymbolGlyph(icon)
            .fontSize(24)
            .fontColor([enabled ? tone : AppColors.Disabled])
        }
      }
      .width(48)
      .height(48)
      .borderRadius(18)
      .backgroundColor(enabled ? surfaceTone : AppColors.SurfaceMuted)

      Column({ space: 4 }) {
        Text(title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(enabled ? AppColors.TextPrimary : AppColors.TextTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(17)
        .fontColor([enabled ? AppColors.TextTertiary : AppColors.Disabled])
    }
    .width('100%')
    .height(74)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: 16,
      right: 14
    })
    .backgroundColor(enabled ? AppColors.SurfaceRaised : AppColors.SurfaceMuted)
    .borderRadius(AppRadii.Large)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .onClick(() => {
      if (enabled) {
        action();
      }
    })
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
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .alignItems(HorizontalAlign.Start)
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
  ExportActionMessageText() {
    InlineMessageSurface({
      message: this.exportActionMessage,
      tone: this.exportActionMessageTone
    })
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
      this.deleteActionMessage.length > 0 || this.exportActionMessage.length > 0 ||
      this.canViewChangeArchiveAction() || this.canViewDeleteArchiveAction() || this.canViewExportArchiveAction();
  }

  canViewChangeArchiveAction(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveUpdateRequestSubmit);
  }

  canViewDeleteArchiveAction(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveDeleteRequestSubmit);
  }

  canViewExportArchiveAction(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveExport);
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

  openExportVerifyPage(): void {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveExport)) {
      this.exportActionMessage = '当前账号无权导出设备档案';
      this.exportActionMessageTone = AppColors.Danger;
      return;
    }

    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/DeviceArchiveExport' });
    } catch (err) {
      this.exportActionMessage = '导出设备档案不可用';
      this.exportActionMessageTone = AppColors.Danger;
    }
  }

  returnToQuery(): void {
    try {
      DeviceArchiveFlowStore.clearFlow();
      const router = this.getUIContext().getRouter();
      router.back({ url: 'pages/ArchiveCenter/DeviceArchiveQuery' });
    } catch (err) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/ArchiveCenter/DeviceArchiveQuery' });
      } catch (replaceErr) {
        try {
          this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
        } catch (toastErr) {
        }
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
      this.canExportArchive = false;
      this.exportActionMessage = '';
      this.detailMessage = '重新获取设备档案失败，请返回查询';
      this.detailMessageTone = AppColors.Danger;
    }
  }
}


