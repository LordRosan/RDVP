import { AppColors, AppSpacing } from '../styles/AppTheme';
import { ActionTile } from '../components/ActionTile';
import { AppSectionTitle } from '../components/AppSectionTitle';
import { HeaderCircleButton } from '../components/HeaderCircleButton';
import { HeroSurface } from '../components/HeroSurface';
import { InlineMessageSurface } from '../components/InlineMessageSurface';
import { MetricTile } from '../components/MetricTile';
import { SummaryPanel } from '../components/SummaryPanel';
import { WorkbenchAction, WorkbenchActionId, WorkbenchMetric, WorkbenchStatusItem } from '../models/app/WorkbenchModels';
import { CurrentUserSnapshot } from '../models/identity/SessionModels';
import { WorkbenchService } from '../services/app/WorkbenchService';
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
    WorkbenchService.refreshSummaryRemoteFirst().then(() => {
      this.applyWorkbenchState();
    }).catch(() => {
    });
  }

  applyWorkbenchState(): void {
    this.metrics = WorkbenchService.getMetrics();
    this.actions = WorkbenchService.getActions();
    this.statusItems = WorkbenchService.getStatusItems();
    this.currentUser = SessionStore.getCurrentUser();
  }

  build() {
    Scroll() {
      Column({ space: AppSpacing.Section }) {
        this.Header()
        this.MetricSection()
        this.ActionSection()
        this.StatusSection()
      }
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: AppSpacing.PageX,
        right: AppSpacing.PageX,
        top: 18,
        bottom: AppSpacing.PageBottom
      })
      .width('100%')
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  Header() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        HeroSurface({
          eyebrow: this.getUserEyebrow(),
          title: 'RDVP 工作台',
          subtitle: '集中处理设备档案、现场运维、审核和记录追溯。',
          icon: $r('sys.symbol.checkmark_shield'),
          tone: AppColors.Primary
        })
          .layoutWeight(1)

        this.PersonalCenterButton()
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      this.PersonalCenterMessageText()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  MetricSection() {
    SummaryPanel({
      title: '中心概览',
      caption: '按当前账号权限展示可处理事项。'
    }) {
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
  }

  @Builder
  ActionSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '业务中心',
        subtitle: '进入对应中心继续处理授权业务。'
      })

      Grid() {
        ForEach(this.actions, (item: WorkbenchAction) => {
          GridItem() {
            Column({ space: 8 }) {
              if (this.actionMessageTargetId === `${item.id}` && this.actionMessage.length > 0) {
                InlineMessageSurface({
                  message: this.actionMessage,
                  tone: AppColors.Danger
                })
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
      InlineMessageSurface({
        message: this.personalCenterMessage,
        tone: AppColors.Danger
      })
    }
  }

  @Builder
  StatusSection() {
    SummaryPanel({
      title: '系统状态',
      caption: '登录态与后端服务连接状态。'
    }) {
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
    HeaderCircleButton({
      icon: $r('sys.symbol.person_crop_circle_fill'),
      action: () => {
        this.openPersonalCenter();
      }
    })
  }

  getUserEyebrow(): string {
    const username = this.currentUser.username === undefined ? '' : this.currentUser.username;
    const displayName = this.currentUser.displayName.length > 0 ? this.currentUser.displayName : username;
    if (displayName.length > 0) {
      return `${displayName} 的业务入口`;
    }

    return '统一业务入口';
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
