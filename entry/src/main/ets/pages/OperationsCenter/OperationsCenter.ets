import { AppColors } from '../../styles/AppTheme';
import { ActionTile } from '../../components/ActionTile';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { OperationsCenterPermissions, PermissionCode } from '../../models/PermissionModels';
import { WorkbenchAction, WorkbenchActionId } from '../../models/WorkbenchModels';
import { ApiClient } from '../../services/ApiClient';
import { WorkbenchService } from '../../services/WorkbenchService';
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
        if (SessionStore.hasPermission(PermissionCode.OpsRepairReportCreate)) {
          StatusInfoRow({
            label: '待维修任务数',
            value: this.getActiveRepairTaskText(),
            tone: AppColors.Warning
          })
          this.CardDivider()
        }
        if (SessionStore.hasPermission(PermissionCode.OpsReinspectionCreate)) {
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
    if (SessionStore.hasPermission(PermissionCode.OpsDeviceVerify)) {
      parts.push('可核验');
    }
    if (SessionStore.hasPermission(PermissionCode.OpsRepairTaskAccept)) {
      parts.push('可接取');
    }
    if (SessionStore.hasPermission(PermissionCode.OpsRepairReportCreate)) {
      parts.push('可维修');
    }
    if (SessionStore.hasPermission(PermissionCode.OpsReinspectionCreate)) {
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

    if (action.id === WorkbenchActionId.RepairTaskPool) {
      this.openPage('pages/OperationsCenter/RepairTaskPool', '任务接取不可用');
      return;
    }

    if (action.id === WorkbenchActionId.AcceptedRepairTask) {
      this.openPage('pages/OperationsCenter/AcceptedRepairTask', '维修任务不可用');
      return;
    }

    if (action.id === WorkbenchActionId.ReinspectionTask) {
      this.openPage('pages/OperationsCenter/ReinspectionTask', '复检任务不可用');
      return;
    }

    if (action.id === WorkbenchActionId.OperationsRecord) {
      this.openPage('pages/RecordCenter/OperationsRecord', '运维记录不可用');
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

    if (url === 'pages/OperationsCenter/RepairTaskPool') {
      return `${WorkbenchActionId.RepairTaskPool}`;
    }

    if (url === 'pages/OperationsCenter/AcceptedRepairTask') {
      return `${WorkbenchActionId.AcceptedRepairTask}`;
    }

    if (url === 'pages/OperationsCenter/ReinspectionTask') {
      return `${WorkbenchActionId.ReinspectionTask}`;
    }

    if (url === 'pages/RecordCenter/OperationsRecord') {
      return `${WorkbenchActionId.OperationsRecord}`;
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
