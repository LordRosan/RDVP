import { AppColors } from '../../styles/AppTheme';
import { ActionTile } from '../../components/ActionTile';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { OperationsCenterPermissions, PermissionCode } from '../../models/PermissionModels';
import { WorkbenchAction, WorkbenchActionId } from '../../models/WorkbenchModels';
import { ApiClient } from '../../services/ApiClient';
import { WorkbenchService } from '../../services/WorkbenchService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';

@Entry
@Component
struct OperationsCenter {
  @State actions: WorkbenchAction[] = WorkbenchService.getOperationsCenterActions();
  @State message: string = '';
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
      Column({ space: 6 }) {
        Text('运维中心')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('处理核验、故障、维修和复检任务')
          .fontSize(15)
          .fontColor(AppColors.TextSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Stack() {
        SymbolGlyph($r('sys.symbol.wrench_and_screwdriver'))
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
        if (SessionStore.hasPermission(PermissionCode.OpsRepairTaskAccept)) {
          StatusInfoRow({
            label: '待接取故障',
            value: this.getPendingFaultText(),
            tone: AppColors.Danger
          })
          this.CardDivider()
        }
        if (SessionStore.hasPermission(PermissionCode.OpsRepairReportCreate)) {
          StatusInfoRow({
            label: '已接取维修',
            value: this.getActiveRepairTaskText(),
            tone: AppColors.Warning
          })
          this.CardDivider()
        }
        if (SessionStore.hasPermission(PermissionCode.OpsReinspectionCreate)) {
          StatusInfoRow({
            label: '待复检任务',
            value: this.getPendingReinspectionText(),
            tone: AppColors.Primary
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
          ActionTile({ action: item })
            .onClick(() => {
              this.openFeature(item);
            })
        }, (item: WorkbenchAction) => item.id)
      }
      .width('100%')

      this.MessageText()
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

  getPendingFaultCount(): number {
    if (this.workbenchRefreshRevision < 0) {
      return 0;
    }

    return WorkbenchService.getPendingFaultCount();
  }

  getPendingFaultText(): string {
    return `${this.getPendingFaultCount()}项`;
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
    if (action.id === WorkbenchActionId.DeviceVerification) {
      this.openPage('pages/OperationsCenter/DeviceVerification', '状态核验不可用');
      return;
    }

    if (action.id === WorkbenchActionId.FaultReport) {
      this.openPage('pages/OperationsCenter/FaultReport', '故障报告不可用');
      return;
    }

    if (action.id === WorkbenchActionId.AvailableRepairTask) {
      this.openPage('pages/OperationsCenter/AvailableRepairTask', '附近故障不可用');
      return;
    }

    if (action.id === WorkbenchActionId.MyRepairTask) {
      this.openPage('pages/OperationsCenter/MyRepairTask', '我的维修不可用');
      return;
    }

    if (action.id === WorkbenchActionId.ReinspectionTask) {
      this.openPage('pages/OperationsCenter/ReinspectionTask', '复检任务不可用');
      return;
    }

    this.message = '功能暂不可用';
  }

  openPage(url: string, errorMessage: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url });
    } catch (err) {
      this.message = errorMessage;
    }
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
      this.message = '页面跳转失败';
    }
  }
}
