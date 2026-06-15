import { AppColors } from '../../styles/AppTheme';
import { ActionTile } from '../../components/ActionTile';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { WorkbenchAction, WorkbenchActionId } from '../../models/app/WorkbenchModels';
import { ApiClient } from '../../services/common/ApiClient';
import { WorkbenchService } from '../../services/app/WorkbenchService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';
import { PermissionTextFormatter } from '../../utils/PermissionTextFormatter';

@Entry
@Component
struct ArchiveCenter {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State actions: WorkbenchAction[] = WorkbenchService.getArchiveCenterActions();
  @State message: string = '';
  @State messageTargetId: string = '';
  @StorageLink('rdvp_workbench_refresh_revision') workbenchRefreshRevision: number = 0;

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveQuery)) {
      return;
    }

    this.refreshCenterState();
  }

  onPageShow(): void {
    if (AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveQuery)) {
      this.refreshCenterState();
    }
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.OverviewPanel()
          this.ActionSection()
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
    this.backToWorkbench();
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
        this.backToWorkbench();
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
      Text('档案中心')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 0, bottom: 2 })
  }

  @Builder
  OverviewPanel() {
    Column({ space: 10 }) {
      Text('中心概览')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({
          label: '功能权限',
          value: this.getArchivePermissionText(),
          tone: this.getArchivePermissionTone(),
          valueWidth: '62%',
          valueMaxLines: 3,
          rowMinHeight: 72,
          verticalPadding: 8
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
  ActionSection() {
    Column({ space: 12 }) {
      Text('功能入口')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column({ space: 10 }) {
        ForEach(this.actions, (item: WorkbenchAction) => {
          Column({ space: 8 }) {
            if (this.messageTargetId === `${item.id}` && this.message.length > 0) {
              this.MessageText()
            }

            ActionTile({ action: item })
              .onClick(() => {
                this.openFeature(item);
              })
          }
          .width('100%')
        }, (item: WorkbenchAction) => item.id)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(13)
        .fontColor(AppColors.Danger)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
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

  refreshCenterState(): void {
    this.actions = WorkbenchService.getArchiveCenterActions();
  }

  getArchivePermissionText(): string {
    if (this.workbenchRefreshRevision < 0) {
      return '-';
    }

    const permissions: string[] = [];
    if (SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveQuery)) {
      permissions.push('可查询');
    }

    if (SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveUpdateRequestSubmit)) {
      permissions.push('可修改');
    }

    if (SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveDeleteRequestSubmit)) {
      permissions.push('可删除');
    }

    if (SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveCreateRequestSubmit)) {
      permissions.push('可添加');
    }

    return PermissionTextFormatter.formatTwoPerLine(permissions.length > 0 ? permissions : ['仅查询']);
  }

  getArchivePermissionTone(): string {
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveUpdateRequestSubmit) ||
      SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveCreateRequestSubmit) ||
      SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveDeleteRequestSubmit) ? AppColors.Primary : AppColors.TextSecondary;
  }

  openFeature(action: WorkbenchAction): void {
    this.message = '';
    this.messageTargetId = '';
    if (action.id === WorkbenchActionId.DeviceArchiveQuery) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/DeviceArchiveQuery' });
      } catch (err) {
        this.message = '查询设备档案不可用';
        this.messageTargetId = `${action.id}`;
      }
      return;
    }

    if (action.id === WorkbenchActionId.DeviceArchiveCreateRequest) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/DeviceArchiveCodeVerify' });
      } catch (err) {
        this.message = '添加设备档案不可用';
        this.messageTargetId = `${action.id}`;
      }
      return;
    }

    this.message = '功能暂不可用';
    this.messageTargetId = `${action.id}`;
  }

  backToWorkbench(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/Workbench' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}


