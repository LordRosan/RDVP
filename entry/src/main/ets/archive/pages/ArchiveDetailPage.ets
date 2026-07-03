import { AppColors, AppRadii, AppSpacing } from '../../shared/theme/AppTheme';
import { AppSectionTitle } from '../../shared/components/AppSectionTitle';
import { ArchiveInfoCard } from '../../shared/components/ArchiveInfoCard';
import { InlineMessageSurface } from '../../shared/components/InlineMessageSurface';
import { StatusInfoRow } from '../../shared/components/StatusInfoRow';
import { DeviceStatus, DeviceSummary } from '../models/DeviceModels';
import { PermissionCode } from '../../user/models/PermissionModels';
import { ArchiveSensitiveActionGuardService } from '../services/ArchiveSensitiveActionGuardService';
import { DeviceService } from '../services/DeviceService';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';
import { ArchiveFlowStore } from '../stores/ArchiveFlowStore';
import { SessionStore } from '../../user/stores/SessionStore';
import { AuthGuard } from '../../shared/security/AuthGuard';
import { UiFeedbackTone } from '../../shared/models/UiFeedbackModels';
import { AppNavigator } from '../../shared/navigation/AppNavigator';


@Entry
@Component
struct ArchiveDetailPage {
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
  @State detailMessageTone: string = UiFeedbackTone.Danger;
  @State changeActionMessage: string = '';
  @State changeActionMessageTone: string = UiFeedbackTone.Danger;
  @State deleteActionMessage: string = '';
  @State deleteActionMessageTone: string = UiFeedbackTone.Danger;
  @State canChangeArchive: boolean = false;
  @State canDeleteArchive: boolean = false;
  @State canExportArchive: boolean = false;
  @State exportActionMessage: string = '';
  @State exportActionMessageTone: string = UiFeedbackTone.Danger;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterArchiveQuery)) {
      return;
    }

    this.loadArchiveContext();
  }

  onPageShow(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterArchiveQuery)) {
      return;
    }

    this.loadArchiveContext();
  }

  loadArchiveContext(): void {
    const device = ArchiveFlowStore.getCurrentDevice();
    if (device === undefined) {
      const lastCode = ArchiveFlowStore.getLastDeviceCode();
      if (lastCode.length > 0) {
        this.reloadDeviceByCode(lastCode);
        return;
      }

      this.hasDevice = false;
      this.canChangeArchive = false;
      this.canDeleteArchive = false;
      this.canExportArchive = false;
      this.detailMessage = UiFeedbackService.requiredSelection('档案');
      this.detailMessageTone = UiFeedbackTone.Danger;
      this.changeActionMessage = '';
      this.deleteActionMessage = '';
      this.exportActionMessage = '';
      return;
    }

    this.device = device;
    this.hasDevice = true;
    this.canChangeArchive = SessionStore.hasPermission(PermissionCode.ArchiveCenterArchiveUpdateRequestSubmit) &&
      !DeviceService.isArchiveRequestLocked(device);
    this.canDeleteArchive = SessionStore.hasPermission(PermissionCode.ArchiveCenterArchiveDeleteRequestSubmit) &&
      !DeviceService.isArchiveRequestLocked(device) &&
      !ArchiveSensitiveActionGuardService.isDeleteLocked(device.deviceCode);
    this.canExportArchive = SessionStore.hasPermission(PermissionCode.ArchiveCenterArchiveExport);
    this.detailMessage = '';
    this.detailMessageTone = UiFeedbackTone.Danger;
    this.changeActionMessage = '';
    this.changeActionMessageTone = UiFeedbackTone.Danger;
    this.exportActionMessage = '';
    this.exportActionMessageTone = UiFeedbackTone.Danger;
    if (ArchiveSensitiveActionGuardService.isDeleteLocked(device.deviceCode)) {
      this.deleteActionMessage = ArchiveSensitiveActionGuardService.getDeleteLockMessage(device.deviceCode);
      this.deleteActionMessageTone = UiFeedbackTone.Danger;
      return;
    }

    this.deleteActionMessage = '';
    this.deleteActionMessageTone = UiFeedbackTone.Danger;
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
      Text('档案详情')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '82%' })

      Text('Archive Detail')
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

      ArchiveInfoCard({
        device: this.device
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
        this.DetailActionTile('导出档案', $r('sys.media.ohos_save_button_line'), AppColors.Primary,
          AppColors.PrimarySurface, this.canExportArchive, () => {
            this.openExportVerifyPage();
          }, true)
      }
      if (this.canViewChangeArchiveAction()) {
        this.ChangeActionMessageText()
        this.DetailActionTile('修改档案', $r('sys.symbol.text_clipboard'), AppColors.Primary,
          AppColors.PrimarySurface, this.canChangeArchive, () => {
            this.openChangePage();
          })
      }
      if (this.canViewDeleteArchiveAction()) {
        this.DeleteActionMessageText()
        this.DetailActionTile('删除档案', $r('sys.symbol.trash'), AppColors.Danger,
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
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterArchiveUpdateRequestSubmit);
  }

  canViewDeleteArchiveAction(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterArchiveDeleteRequestSubmit);
  }

  canViewExportArchiveAction(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterArchiveExport);
  }

  openChangePage(): void {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveCenterArchiveUpdateRequestSubmit)) {
      this.changeActionMessage = UiFeedbackService.operationUnavailable('修改档案');
      this.changeActionMessageTone = UiFeedbackTone.Danger;
      return;
    }

    if (DeviceService.isArchiveRequestLocked(this.device)) {
      this.changeActionMessage = DeviceService.formatArchiveRequestLockReason(this.device);
      this.changeActionMessageTone = UiFeedbackTone.Danger;
      return;
    }

    AppNavigator.push(this.getUIContext(), 'archive/pages/ArchiveUpdatePage', () => {
      this.changeActionMessage = UiFeedbackService.operationUnavailable('修改档案');
      this.changeActionMessageTone = UiFeedbackTone.Danger;
    });
  }

  openDeletePage(): void {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveCenterArchiveDeleteRequestSubmit)) {
      this.deleteActionMessage = UiFeedbackService.operationUnavailable('删除档案');
      this.deleteActionMessageTone = UiFeedbackTone.Danger;
      return;
    }

    if (ArchiveSensitiveActionGuardService.isDeleteLocked(this.device.deviceCode)) {
      this.deleteActionMessage = ArchiveSensitiveActionGuardService.getDeleteLockMessage(this.device.deviceCode);
      this.deleteActionMessageTone = UiFeedbackTone.Danger;
      return;
    }

    if (DeviceService.isArchiveRequestLocked(this.device)) {
      this.deleteActionMessage = DeviceService.formatArchiveRequestLockReason(this.device);
      this.deleteActionMessageTone = UiFeedbackTone.Danger;
      return;
    }

    AppNavigator.push(this.getUIContext(), 'archive/pages/ArchiveDeletePage', () => {
      this.deleteActionMessage = UiFeedbackService.operationUnavailable('删除档案');
      this.deleteActionMessageTone = UiFeedbackTone.Danger;
    });
  }

  openExportVerifyPage(): void {
    if (!SessionStore.hasPermission(PermissionCode.ArchiveCenterArchiveExport)) {
      this.exportActionMessage = UiFeedbackService.operationUnavailable('导出档案');
      this.exportActionMessageTone = UiFeedbackTone.Danger;
      return;
    }

    AppNavigator.push(this.getUIContext(), 'archive/pages/ArchiveExportPage', () => {
      this.exportActionMessage = UiFeedbackService.operationUnavailable('导出档案');
      this.exportActionMessageTone = UiFeedbackTone.Danger;
    });
  }

  returnToQuery(): void {
    ArchiveFlowStore.clearFlow();
    if (!AppNavigator.back(this.getUIContext(), () => {
      this.replaceToQuery();
    }, 'archive/pages/ArchiveQueryPage')) {
      this.replaceToQuery();
    }
  }

  replaceToQuery(): void {
    AppNavigator.replace(this.getUIContext(), 'archive/pages/ArchiveQueryPage', () => {
      AppNavigator.showNavigationUnavailableToast(this.getUIContext());
    });
  }

  async reloadDeviceByCode(deviceCode: string): Promise<void> {
    this.detailMessage = UiFeedbackService.sanitize('正在重新获取档案');
    this.detailMessageTone = UiFeedbackTone.Info;
    const response = await DeviceService.queryByCodeRemoteFirst({
      deviceCode
    });
    if (response.success && response.data !== undefined) {
      ArchiveFlowStore.startFlow(response.data);
      this.loadArchiveContext();
    } else {
      this.hasDevice = false;
      this.canChangeArchive = false;
      this.canDeleteArchive = false;
      this.canExportArchive = false;
      this.exportActionMessage = '';
      this.detailMessage = UiFeedbackService.operationUnavailable('查询');
      this.detailMessageTone = UiFeedbackTone.Danger;
    }
  }
}
