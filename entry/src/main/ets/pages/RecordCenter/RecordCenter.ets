import { ActionTile } from '../../components/ActionTile';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { WorkbenchAction, WorkbenchActionId } from '../../models/WorkbenchModels';
import { AppColors } from '../../styles/AppTheme';
import { PermissionTextFormatter } from '../../utils/PermissionTextFormatter';

@Entry
@Component
struct RecordCenter {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State actions: WorkbenchAction[] = this.createActions();
  @State message: string = '';
  @State messageTargetId: string = '';

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
    this.backToManagementCenter();
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
        this.backToManagementCenter();
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
      Text('记录中心')
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
          value: PermissionTextFormatter.formatTwoPerLine(['可查看档案记录', '可查看运维记录', '可查看审核记录']),
          tone: AppColors.Primary,
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

  createActions(): WorkbenchAction[] {
    return [
      {
        id: WorkbenchActionId.ArchiveRecord,
        title: '档案记录',
        tone: AppColors.Primary
      },
      {
        id: WorkbenchActionId.OperationsRecord,
        title: '运维记录',
        tone: AppColors.Primary
      },
      {
        id: WorkbenchActionId.ReviewRecord,
        title: '审核记录',
        tone: AppColors.Primary
      }
    ];
  }

  openFeature(action: WorkbenchAction): void {
    this.message = '';
    this.messageTargetId = '';
    if (action.id === WorkbenchActionId.ArchiveRecord) {
      this.openSubPage('pages/RecordCenter/ArchiveRecord', '档案记录不可用', action.id);
      return;
    }

    if (action.id === WorkbenchActionId.OperationsRecord) {
      this.openSubPage('pages/RecordCenter/OperationsRecord', '运维记录不可用', action.id);
      return;
    }

    if (action.id === WorkbenchActionId.ReviewRecord) {
      this.openSubPage('pages/RecordCenter/ReviewRecord', '审核记录不可用', action.id);
      return;
    }

    this.message = '功能暂不可用';
    this.messageTargetId = `${action.id}`;
  }

  openSubPage(url: string, errorMessage: string, actionId: WorkbenchActionId): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url });
    } catch (err) {
      this.message = errorMessage;
      this.messageTargetId = `${actionId}`;
    }
  }

  backToManagementCenter(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/ManagementCenter/ManagementCenter' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
