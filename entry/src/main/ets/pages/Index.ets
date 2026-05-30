import { ActionTile } from '../components/ActionTile';
import { MetricTile } from '../components/MetricTile';
import { WorkbenchAction, WorkbenchActionId, WorkbenchMetric, WorkbenchStatusItem } from '../models/WorkbenchModels';
import { CurrentUserSnapshot } from '../models/SessionModels';
import { WorkbenchService } from '../services/WorkbenchService';
import { SessionStore } from '../stores/SessionStore';

@Entry
@Component
struct Index {
  @State metrics: WorkbenchMetric[] = WorkbenchService.getMetrics();
  @State actions: WorkbenchAction[] = WorkbenchService.getActions();
  @State statusItems: WorkbenchStatusItem[] = WorkbenchService.getStatusItems();
  @State currentUser: CurrentUserSnapshot = SessionStore.getCurrentUser();
  @State actionMessage: string = '';
  @StorageLink('rdvp_workbench_refresh_revision') workbenchRefreshRevision: number = 0;

  aboutToAppear(): void {
    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    this.refreshWorkbenchState();
  }

  onPageShow(): void {
    if (SessionStore.isAuthenticated()) {
      this.refreshWorkbenchState();
    }
  }

  refreshWorkbenchState(): void {
    this.metrics = WorkbenchService.getMetrics();
    this.actions = WorkbenchService.getActions();
    this.statusItems = WorkbenchService.getStatusItems();
    this.currentUser = SessionStore.getCurrentUser();
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        this.Header()
        this.MetricSection()
        this.ActionSection()
        this.StatusSection()
      }
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: 18,
        right: 18,
        top: 18,
        bottom: 28
      })
      .width('100%')
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#F6F8FB')
  }

  @Builder
  Header() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('RDVP')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .maxLines(1)

          Text('远程设备核验与运维报告系统')
            .fontSize(13)
            .fontColor('#5B6472')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        this.PersonalCenterButton()
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
  }

  @Builder
  MetricSection() {
    Column({ space: 12 }) {
      Text('中心概览')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')

      Grid() {
        ForEach(WorkbenchService.getMetrics(), (item: WorkbenchMetric) => {
          GridItem() {
            MetricTile({
              label: item.label,
              value: item.value,
              status: item.status,
              tone: item.tone
            })
          }
        }, (item: WorkbenchMetric) => `${item.id}-${this.workbenchRefreshRevision}`)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(12)
      .rowsGap(12)
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  ActionSection() {
    Column({ space: 12 }) {
      Text('业务中心')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')

      Grid() {
        ForEach(this.actions, (item: WorkbenchAction) => {
          GridItem() {
            ActionTile({
              action: item
            })
              .onClick(() => {
                this.openAction(item);
              })
          }
        }, (item: WorkbenchAction) => item.id)
      }
      .columnsTemplate('1fr')
      .rowsGap(10)
      .width('100%')

      if (this.actionMessage.length > 0) {
        Text(this.actionMessage)
          .fontSize(13)
          .fontColor('#D9480F')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  StatusSection() {
    Column({ space: 12 }) {
      Text('系统状态')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')

      Column() {
        ForEach(WorkbenchService.getStatusItems(), (item: WorkbenchStatusItem) => {
          Row() {
            Text(item.name)
              .fontSize(14)
              .fontColor('#374151')
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(item.value)
              .fontSize(13)
              .fontColor(item.tone)
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .height(44)
          .width('100%')
          .padding({
            left: 14,
            right: 14
          })
        }, (item: WorkbenchStatusItem) => item.id)
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(8)
      .border({
        width: 1,
        color: '#E5E7EB'
      })

    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  openLoginPage(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Login' });
    } catch (err) {
      this.actionMessage = '登录页不可用';
    }
  }

  @Builder
  PersonalCenterButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
        .fontSize(31)
        .fontColor(['#111827'])
    }
    .width(58)
    .height(58)
    .backgroundColor('#FFFFFF')
    .border({
      width: 1,
      color: '#E5E7EB'
    })
    .onClick(() => {
      this.openPersonalCenter();
    })
  }

  openPersonalCenter(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/PersonalCenter' });
    } catch (err) {
      this.actionMessage = '个人中心不可用';
    }
  }

  openAction(action: WorkbenchAction): void {
    this.actionMessage = '';

    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    if (action.id === WorkbenchActionId.ArchiveCenter) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter' });
      } catch (err) {
        this.actionMessage = '档案中心不可用';
      }
      return;
    }

    if (action.id === WorkbenchActionId.OperationsCenter) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/OperationsCenter' });
      } catch (err) {
        this.actionMessage = '运维中心不可用';
      }
      return;
    }

    if (action.id === WorkbenchActionId.ManagementCenter) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ManagementCenter' });
      } catch (err) {
        this.actionMessage = '管理中心不可用';
      }
      return;
    }

    if (action.id === WorkbenchActionId.DeviceQuery) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/DeviceArchiveQuery' });
      } catch (err) {
        this.actionMessage = '设备档案查询不可用';
      }
      return;
    }

    if (action.id === WorkbenchActionId.DeviceVerification) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/DeviceVerification' });
      } catch (err) {
        this.actionMessage = '状态核验不可用';
      }
      return;
    }

    if (action.id === WorkbenchActionId.FaultReport) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/FaultReport' });
      } catch (err) {
        this.actionMessage = '故障报告不可用';
      }
      return;
    }

    if (action.id === WorkbenchActionId.AvailableRepairTask) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/AvailableRepairTask' });
      } catch (err) {
        this.actionMessage = '附近故障不可用';
      }
      return;
    }

    if (action.id === WorkbenchActionId.MyRepairTask) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/MyRepairTask' });
      } catch (err) {
        this.actionMessage = '我的维修不可用';
      }
      return;
    }

    if (action.id === WorkbenchActionId.ReinspectionTask) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ReinspectionTask' });
      } catch (err) {
        this.actionMessage = '复检任务不可用';
      }
      return;
    }

    if (action.id === WorkbenchActionId.DeviceChangeReview) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/DeviceArchiveReview' });
      } catch (err) {
        this.actionMessage = '变更审核不可用';
      }
      return;
    }

    if (action.id === WorkbenchActionId.OperationRecord) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/OperationRecord' });
      } catch (err) {
        this.actionMessage = '操作记录不可用';
      }
      return;
    }

    this.actionMessage = '功能暂不可用';
  }
}
