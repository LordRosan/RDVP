import { AppColors } from '../styles/AppTheme';
import { ActionTile } from '../components/ActionTile';
import { MetricTile } from '../components/MetricTile';
import { WorkbenchAction, WorkbenchActionId, WorkbenchMetric, WorkbenchStatusItem } from '../models/WorkbenchModels';
import { CurrentUserSnapshot } from '../models/SessionModels';
import { OfflineSyncProcessorService } from '../services/OfflineSyncProcessorService';
import { OfflineSyncService } from '../services/OfflineSyncService';
import { WorkbenchService } from '../services/WorkbenchService';
import { SessionStore } from '../stores/SessionStore';

@Entry
@Component
struct Workbench {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State metrics: WorkbenchMetric[] = WorkbenchService.getMetrics();
  @State actions: WorkbenchAction[] = WorkbenchService.getActions();
  @State statusItems: WorkbenchStatusItem[] = WorkbenchService.getStatusItems();
  @State currentUser: CurrentUserSnapshot = SessionStore.getCurrentUser();
  @State actionMessage: string = '';
  @State actionMessageTargetId: string = '';
  @State personalCenterMessage: string = '';
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
    this.applyWorkbenchState();
    this.runAutoSyncIfEnabled().then(() => {
      return WorkbenchService.refreshSummaryRemoteFirst();
    }).then(() => {
      this.applyWorkbenchState();
    }).catch(() => {
      WorkbenchService.refreshSummaryRemoteFirst().then(() => {
        this.applyWorkbenchState();
      });
    });
  }

  applyWorkbenchState(): void {
    this.metrics = WorkbenchService.getMetrics();
    this.actions = WorkbenchService.getActions();
    this.statusItems = WorkbenchService.getStatusItems();
    this.currentUser = SessionStore.getCurrentUser();
  }

  async runAutoSyncIfEnabled(): Promise<void> {
    if (!OfflineSyncService.isAutoSyncEnabled()) {
      return;
    }

    try {
      const result = await OfflineSyncProcessorService.syncReadyItems(OfflineSyncService.getAutoSyncBatchLimit());
      OfflineSyncService.recordAutoSyncResult(result);
    } catch (err) {
      OfflineSyncService.recordAutoSyncResult({
        processedCount: 0,
        syncedCount: 0,
        failedCount: 1,
        skippedCount: 0,
        message: '自动同步执行失败',
        itemResults: []
      });
    }
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
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  Header() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('RDVP')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)

          Text('远程设备核验与运维报告系统')
            .fontSize(13)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          this.PersonalCenterMessageText()
          this.PersonalCenterButton()
        }
        .alignItems(HorizontalAlign.End)
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
        .fontColor(AppColors.TextPrimary)

      Grid() {
        ForEach(this.metrics, (item: WorkbenchMetric) => {
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
        .fontColor(AppColors.TextPrimary)

      Grid() {
        ForEach(this.actions, (item: WorkbenchAction) => {
          GridItem() {
            Column({ space: 8 }) {
              if (this.actionMessageTargetId === `${item.id}` && this.actionMessage.length > 0) {
                Text(this.actionMessage)
                  .fontSize(13)
                  .fontColor(AppColors.Danger)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }

              ActionTile({
                action: item
              })
                .onClick(() => {
                  this.openCenter(item);
                })
            }
            .width('100%')
          }
        }, (item: WorkbenchAction) => item.id)
      }
      .columnsTemplate('1fr')
      .rowsGap(10)
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  PersonalCenterMessageText() {
    if (this.personalCenterMessage.length > 0) {
      Text(this.personalCenterMessage)
        .fontSize(12)
        .fontColor(AppColors.Danger)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(92)
        .textAlign(TextAlign.End)
    }
  }

  @Builder
  StatusSection() {
    Column({ space: 12 }) {
      Text('系统状态')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)

      Column() {
        ForEach(this.statusItems, (item: WorkbenchStatusItem) => {
          Row() {
            Text(item.name)
              .fontSize(14)
              .fontColor(AppColors.TextSecondary)
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
      .backgroundColor(AppColors.Surface)
      .borderRadius(8)
      .border({
        width: 1,
        color: AppColors.Divider
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
      this.actionMessageTargetId = `${WorkbenchActionId.ArchiveCenter}`;
    }
  }

  @Builder
  PersonalCenterButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
        .fontSize(31)
        .fontColor([AppColors.TextPrimary])
    }
    .width(58)
    .height(58)
    .backgroundColor(AppColors.Surface)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .onClick(() => {
      this.openPersonalCenter();
    })
  }

  openPersonalCenter(): void {
    this.personalCenterMessage = '';
    this.actionMessage = '';
    this.actionMessageTargetId = '';
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/PersonalCenter/PersonalCenter' });
    } catch (err) {
      this.personalCenterMessage = '个人中心不可用';
    }
  }

  openCenter(action: WorkbenchAction): void {
    this.actionMessage = '';
    this.actionMessageTargetId = '';
    this.personalCenterMessage = '';

    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    if (action.id === WorkbenchActionId.ArchiveCenter) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/ArchiveCenter' });
      } catch (err) {
        this.actionMessage = '档案中心不可用';
        this.actionMessageTargetId = `${action.id}`;
      }
      return;
    }

    if (action.id === WorkbenchActionId.OperationsCenter) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/OperationsCenter/OperationsCenter' });
      } catch (err) {
        this.actionMessage = '运维中心不可用';
        this.actionMessageTargetId = `${action.id}`;
      }
      return;
    }

    if (action.id === WorkbenchActionId.SyncCenter) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/SyncCenter/SyncCenter' });
      } catch (err) {
        this.actionMessage = '同步中心不可用';
        this.actionMessageTargetId = `${action.id}`;
      }
      return;
    }

    if (action.id === WorkbenchActionId.ManagementCenter) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ManagementCenter/ManagementCenter' });
      } catch (err) {
        this.actionMessage = '管理中心不可用';
        this.actionMessageTargetId = `${action.id}`;
      }
      return;
    }

    this.actionMessage = '中心入口暂不可用';
    this.actionMessageTargetId = `${action.id}`;
  }
}
