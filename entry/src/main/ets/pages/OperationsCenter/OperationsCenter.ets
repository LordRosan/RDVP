import { AppColors } from '../../styles/AppTheme';
import { ActionTile } from '../../components/ActionTile';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { OperationsCenterPermissions, PermissionCode } from '../../models/identity/PermissionModels';
import { WorkbenchAction, WorkbenchActionId } from '../../models/app/WorkbenchModels';
import { ApiClient } from '../../services/common/ApiClient';
import { WorkbenchService } from '../../services/app/WorkbenchService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';
import { PermissionTextFormatter } from '../../utils/PermissionTextFormatter';

@Entry
@Component
struct OperationsCenter {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State actions: WorkbenchAction[] = WorkbenchService.getOperationsCenterActions();
  @State message: string = '';
  @State messageTargetId: string = '';
  @StorageLink('rdvp_workbench_refresh_revision') workbenchRefreshRevision: number = 0;

  aboutToAppear(): void {
    if (!AuthGuard.requireAnyPermission(this.getUIContext(), OperationsCenterPermissions)) {
      return;
    }

    this.refreshCenterState();
  }

  onPageShow(): void {
    if (AuthGuard.requireAnyPermission(this.getUIContext(), OperationsCenterPermissions)) {
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
        Text('运维中心')
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
          value: this.getPermissionSummaryText(),
          tone: AppColors.Primary,
          valueWidth: '62%',
          valueMaxLines: 3,
          rowMinHeight: 72,
          verticalPadding: 8
        })
        this.CardDivider()
        if (SessionStore.hasPermission(PermissionCode.OperationsCenterRepairReportSubmit)) {
          StatusInfoRow({
            label: '待维修任务数',
            value: this.getActiveRepairTaskText(),
            tone: AppColors.Warning
          })
          this.CardDivider()
        }
        if (SessionStore.hasPermission(PermissionCode.OperationsCenterReinspectionReportSubmit)) {
          StatusInfoRow({
            label: '待复检任务数',
            value: this.getPendingReinspectionText(),
            tone: AppColors.Primary
          })
        }
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
    this.actions = WorkbenchService.getOperationsCenterActions();
    WorkbenchService.refreshSummaryRemoteFirst().then(() => {
      this.actions = WorkbenchService.getOperationsCenterActions();
    });
  }

  getPermissionSummaryText(): string {
    const parts: string[] = [];
    if (SessionStore.hasPermission(PermissionCode.OperationsCenterDeviceVerificationSubmit)) {
      parts.push('可核验');
    }
    if (SessionStore.hasPermission(PermissionCode.OperationsCenterRepairTaskAccept)) {
      parts.push('可接取');
    }
    if (SessionStore.hasPermission(PermissionCode.OperationsCenterRepairReportSubmit)) {
      parts.push('可维修');
    }
    if (SessionStore.hasPermission(PermissionCode.OperationsCenterReinspectionReportSubmit)) {
      parts.push('可复检');
    }
    return PermissionTextFormatter.formatTwoPerLine(parts);
  }

  getActiveRepairTaskText(): string {
    return `${WorkbenchService.getActiveRepairTaskCount()}项`;
  }

  getPendingReinspectionCount(): number {
    if (this.workbenchRefreshRevision < 0) {
      return 0;
    }

    return WorkbenchService.getPendingReinspectionCount();
  }

  getPendingReinspectionText(): string {
    return `${this.getPendingReinspectionCount()}项`;
  }

  openFeature(action: WorkbenchAction): void {
    this.message = '';
    this.messageTargetId = '';
    if (action.id === WorkbenchActionId.DeviceVerification) {
      this.openPage('pages/OperationsCenter/DeviceVerification', '核验与报修不可用');
      return;
    }

    if (action.id === WorkbenchActionId.TaskAcceptance) {
      this.openPage('pages/OperationsCenter/TaskAcceptance', '任务接取不可用');
      return;
    }

    if (action.id === WorkbenchActionId.RepairReport) {
      this.openPage('pages/OperationsCenter/RepairReport', '维修任务不可用');
      return;
    }

    if (action.id === WorkbenchActionId.ReinspectionReport) {
      this.openPage('pages/OperationsCenter/ReinspectionReport', '复检任务不可用');
      return;
    }

    if (action.id === WorkbenchActionId.OperationRecordQuery) {
      this.openPage('pages/ManagementCenter/RecordQuery/OperationRecordQuery', '运维记录不可用');
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
    if (url === 'pages/OperationsCenter/DeviceVerification') {
      return `${WorkbenchActionId.DeviceVerification}`;
    }

    if (url === 'pages/OperationsCenter/TaskAcceptance') {
      return `${WorkbenchActionId.TaskAcceptance}`;
    }

    if (url === 'pages/OperationsCenter/RepairReport') {
      return `${WorkbenchActionId.RepairReport}`;
    }

    if (url === 'pages/OperationsCenter/ReinspectionReport') {
      return `${WorkbenchActionId.ReinspectionReport}`;
    }

    if (url === 'pages/ManagementCenter/RecordQuery/OperationRecordQuery') {
      return `${WorkbenchActionId.OperationRecordQuery}`;
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


