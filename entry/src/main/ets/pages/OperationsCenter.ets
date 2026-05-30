import { ActionTile } from '../components/ActionTile';
import { StatusInfoRow } from '../components/StatusInfoRow';
import { WorkbenchAction, WorkbenchActionId } from '../models/WorkbenchModels';
import { ApiClient } from '../services/ApiClient';
import { WorkbenchService } from '../services/WorkbenchService';
import { AuthGuard } from '../utils/AuthGuard';

@Entry
@Component
struct OperationsCenter {
  @State actions: WorkbenchAction[] = WorkbenchService.getOperationsCenterActions();
  @State message: string = '';
  @StorageLink('rdvp_workbench_refresh_revision') workbenchRefreshRevision: number = 0;

  aboutToAppear(): void {
    if (!AuthGuard.requireAuthenticated(this.getUIContext())) {
      return;
    }

    this.refreshCenterState();
  }

  onPageShow(): void {
    if (AuthGuard.requireAuthenticated(this.getUIContext())) {
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
    .backgroundColor('#F2F5F7')
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
          .fontColor(['#111827'])
      }
      .width(44)
      .height(44)
      .backgroundColor('#FFFFFF')
      .border({
        width: 1,
        color: '#E5E7EB'
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
    .backgroundColor('#F2F5F7')
  }

  @Builder
  ModeHeader() {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text('运维中心')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('处理核验、故障、维修和复检任务')
          .fontSize(15)
          .fontColor('#6B7280')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Stack() {
        SymbolGlyph($r('sys.symbol.wrench_and_screwdriver'))
          .fontSize(31)
          .fontColor(['#111827'])
      }
      .width(58)
      .height(58)
      .borderRadius(29)
      .backgroundColor('#FFFFFF')
      .border({
        width: 1,
        color: '#E5E7EB'
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
        .fontColor('#111827')
        .maxLines(1)

      Column() {
        StatusInfoRow({
          label: '待接取故障',
          value: `${this.getPendingFaultCount()}项`,
          tone: '#D9480F'
        })
        this.CardDivider()
        StatusInfoRow({
          label: '待复检任务',
          value: `${this.getPendingReinspectionCount()}项`,
          tone: '#845EF7'
        })
        this.CardDivider()
        StatusInfoRow({
          label: '服务状态',
          value: ApiClient.getRuntimeStatusLabel(),
          tone: ApiClient.getRuntimeStatusTone()
        })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
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
        .fontColor('#111827')
        .maxLines(1)

      Column({ space: 10 }) {
        ForEach(this.actions, (item: WorkbenchAction) => {
          ActionTile({ action: item })
            .onClick(() => {
              this.openAction(item);
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
        .fontColor('#D9480F')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor('#E5E7EB')
      .margin({
        left: 18,
        right: 18
      })
  }

  refreshCenterState(): void {
    this.actions = WorkbenchService.getOperationsCenterActions();
  }

  getPendingFaultCount(): number {
    if (this.workbenchRefreshRevision < 0) {
      return 0;
    }

    return WorkbenchService.getPendingFaultCount();
  }

  getPendingReinspectionCount(): number {
    if (this.workbenchRefreshRevision < 0) {
      return 0;
    }

    return WorkbenchService.getPendingReinspectionCount();
  }

  openAction(action: WorkbenchAction): void {
    this.message = '';
    if (action.id === WorkbenchActionId.DeviceVerification) {
      this.openPage('pages/DeviceVerification', '状态核验不可用');
      return;
    }

    if (action.id === WorkbenchActionId.FaultReport) {
      this.openPage('pages/FaultReport', '故障报告不可用');
      return;
    }

    if (action.id === WorkbenchActionId.AvailableRepairTask) {
      this.openPage('pages/AvailableRepairTask', '附近故障不可用');
      return;
    }

    if (action.id === WorkbenchActionId.MyRepairTask) {
      this.openPage('pages/MyRepairTask', '我的维修不可用');
      return;
    }

    if (action.id === WorkbenchActionId.ReinspectionTask) {
      this.openPage('pages/ReinspectionTask', '复检任务不可用');
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

      router.replaceUrl({ url: 'pages/Index' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }
}
