import { AppColors } from '../../styles/AppTheme';
import { ActionTile } from '../../components/ActionTile';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { ManagementCenterPermissions, PermissionCode } from '../../models/PermissionModels';
import { WorkbenchAction, WorkbenchActionId } from '../../models/WorkbenchModels';
import { ApiClient } from '../../services/ApiClient';
import { WorkbenchService } from '../../services/WorkbenchService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';

@Entry
@Component
struct ManagementCenter {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State actions: WorkbenchAction[] = WorkbenchService.getManagementCenterActions();
  @State message: string = '';
  @State messageTargetId: string = '';
  @StorageLink('rdvp_workbench_refresh_revision') workbenchRefreshRevision: number = 0;

  aboutToAppear(): void {
    if (!AuthGuard.requireAnyPermission(this.getUIContext(), ManagementCenterPermissions)) {
      return;
    }

    this.refreshCenterState();
  }

  onPageShow(): void {
    if (AuthGuard.requireAnyPermission(this.getUIContext(), ManagementCenterPermissions)) {
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
      Column({ space: 6 }) {
        Text('管理中心')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('处理审核事项并查看操作记录')
          .fontSize(15)
          .fontColor(AppColors.TextSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Stack() {
        SymbolGlyph($r('sys.symbol.checkmark_shield'))
          .fontSize(31)
          .fontColor([AppColors.TextPrimary])
      }
      .width(58)
      .height(58)
      .borderRadius(29)
      .backgroundColor(AppColors.Surface)
      .border({
        width: 1,
        color: AppColors.Divider
      })
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
        if (SessionStore.hasPermission(PermissionCode.MgmtArchiveChangeReview)) {
          StatusInfoRow({
            label: '待审核变更',
            value: this.getPendingReviewText(),
            tone: AppColors.Primary
          })
          this.CardDivider()
        }
        if (SessionStore.hasPermission(PermissionCode.MgmtAuditLogRead)) {
          StatusInfoRow({
            label: '操作记录',
            value: this.getOperationRecordText(),
            tone: AppColors.TextSecondary
          })
          this.CardDivider()
        }
        StatusInfoRow({
          label: '服务模式',
          value: ApiClient.getRuntimeStatusLabel(),
          tone: ApiClient.getRuntimeStatusTone()
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
    this.actions = WorkbenchService.getManagementCenterActions();
    WorkbenchService.refreshSummaryRemoteFirst().then(() => {
      this.actions = WorkbenchService.getManagementCenterActions();
    });
  }

  getPendingReviewText(): string {
    if (this.workbenchRefreshRevision < 0) {
      return '-';
    }

    return `${WorkbenchService.getPendingChangeCount()}项`;
  }

  getOperationRecordText(): string {
    return '可查看';
  }

  openFeature(action: WorkbenchAction): void {
    this.message = '';
    this.messageTargetId = '';
    if (action.id === WorkbenchActionId.DeviceChangeReview) {
      this.openPage('pages/ManagementCenter/DeviceArchiveReview', '变更审核不可用');
      return;
    }

    if (action.id === WorkbenchActionId.OperationRecord) {
      this.openPage('pages/ManagementCenter/OperationRecord', '操作记录不可用');
      return;
    }

    this.message = '功能暂不可用';
    this.messageTargetId = `${action.id}`;
  }

  openPage(url: string, errorMessage: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url });
    } catch (err) {
      this.message = errorMessage;
      this.messageTargetId = this.resolveActionIdByUrl(url);
    }
  }

  resolveActionIdByUrl(url: string): string {
    if (url === 'pages/ManagementCenter/DeviceArchiveReview') {
      return `${WorkbenchActionId.DeviceChangeReview}`;
    }

    if (url === 'pages/ManagementCenter/OperationRecord') {
      return `${WorkbenchActionId.OperationRecord}`;
    }

    return '';
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
