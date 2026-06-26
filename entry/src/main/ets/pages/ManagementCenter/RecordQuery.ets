import { ActionTile } from '../../components/ActionTile';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { MainPageAction, MainPageActionId } from '../../models/app/MainPageModels';
import { ManagementCenterRecordPermissions, PermissionCode } from '../../models/identity/PermissionModels';
import { UiFeedbackService } from '../../services/common/UiFeedbackService';
import { SessionStore } from '../../stores/SessionStore';
import { AppColors, AppSpacing, AppTone } from '../../styles/AppTheme';
import { AuthGuard } from '../../utils/AuthGuard';
import { UiFeedbackTone } from '../../models/common/UiFeedbackModels';
import { AppNavigator } from '../../utils/AppNavigator';

@Entry
@Component
struct RecordQuery {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State actions: MainPageAction[] = this.createActions();
  @State message: string = '';
  @State messageTargetId: string = '';

  aboutToAppear(): void {
    if (!AuthGuard.requireAnyPermission(this.getUIContext(), ManagementCenterRecordPermissions)) {
      return;
    }

    this.actions = this.createActions();
  }

  onPageShow(): void {
    if (AuthGuard.requireAnyPermission(this.getUIContext(), ManagementCenterRecordPermissions)) {
      this.actions = this.createActions();
    }
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: AppSpacing.Section }) {
          this.Header()
          this.OverviewPanel()
          this.ActionSection()
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .padding({
          left: AppSpacing.PageX,
          right: AppSpacing.PageX,
          top: 0,
          bottom: AppSpacing.PageBottom
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
    CenterTitleBar({
      action: () => {
        this.backToManagementCenter();
      }
    })
  }

  @Builder
  Header() {
    Column({ space: 5 }) {
      Text('记录查询')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Record Query')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 12, bottom: 6 })
  }

  @Builder
  OverviewPanel() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '功能权限',
        subtitle: ''
      })

      Column({ space: 16 }) {
        Grid() {
          GridItem() {
            this.PermissionCell('档案记录', this.canQueryArchiveRecord())
          }

          GridItem() {
            this.PermissionCell('运维记录', this.canQueryOperationsRecord())
          }

          GridItem() {
            this.PermissionCell('审核记录', this.canQueryReviewRecord())
          }
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(14)
        .rowsGap(14)
        .width('100%')
      }
      .width('100%')
      .padding(18)
      .backgroundColor(AppColors.SurfaceRaised)
      .borderRadius(24)
      .border({
        width: 1,
        color: AppColors.Divider
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  PermissionCell(label: string, available: boolean) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Text('')
        .width(8)
        .height(8)
        .backgroundColor(available ? AppColors.Success : AppColors.Danger)
        .borderRadius(4)
    }
    .width('100%')
    .height(40)
    .padding({
      left: 12,
      right: 12
    })
    .backgroundColor(AppColors.SurfaceMuted)
    .borderRadius(16)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  ActionSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '功能入口',
        subtitle: ''
      })

      Column({ space: 10 }) {
        ForEach(this.actions, (item: MainPageAction) => {
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
        }, (item: MainPageAction) => item.id)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      InlineMessageSurface({
        message: this.message,
        tone: UiFeedbackTone.Danger
      })
    }
  }

  createActions(): MainPageAction[] {
    const actions: MainPageAction[] = [];
    if (SessionStore.hasPermission(PermissionCode.ManagementCenterArchiveRecordQuery)) {
      actions.push({
        id: MainPageActionId.ArchiveRecordQuery,
        title: '档案记录',
        tone: AppTone.Warning
      });
    }
    if (SessionStore.hasPermission(PermissionCode.ManagementCenterOperationsRecordQuery)) {
      actions.push({
        id: MainPageActionId.OperationsRecordQuery,
        title: '运维记录',
        tone: AppTone.Warning
      });
    }
    if (SessionStore.hasPermission(PermissionCode.ManagementCenterReviewRecordQuery)) {
      actions.push({
        id: MainPageActionId.ReviewRecordQuery,
        title: '审核记录',
        tone: AppTone.Warning
      });
    }

    return actions;
  }

  canQueryArchiveRecord(): boolean {
    return SessionStore.hasPermission(PermissionCode.ManagementCenterArchiveRecordQuery);
  }

  canQueryOperationsRecord(): boolean {
    return SessionStore.hasPermission(PermissionCode.ManagementCenterOperationsRecordQuery);
  }

  canQueryReviewRecord(): boolean {
    return SessionStore.hasPermission(PermissionCode.ManagementCenterReviewRecordQuery);
  }

  openFeature(action: MainPageAction): void {
    this.message = '';
    this.messageTargetId = '';
    if (action.id === MainPageActionId.ArchiveRecordQuery) {
      this.openSubPage('pages/ManagementCenter/ArchiveRecordQuery', UiFeedbackService.operationUnavailable('档案记录'), action.id);
      return;
    }

    if (action.id === MainPageActionId.OperationsRecordQuery) {
      this.openSubPage('pages/ManagementCenter/OperationsRecordQuery', UiFeedbackService.operationUnavailable('运维记录'), action.id);
      return;
    }

    if (action.id === MainPageActionId.ReviewRecordQuery) {
      this.openSubPage('pages/ManagementCenter/ReviewRecordQuery', UiFeedbackService.operationUnavailable('审核记录'), action.id);
      return;
    }

    this.message = UiFeedbackService.operationUnavailable('操作');
    this.messageTargetId = `${action.id}`;
  }

  openSubPage(url: string, errorMessage: string, actionId: MainPageActionId): void {
    AppNavigator.push(this.getUIContext(), url, () => {
      this.message = errorMessage;
      this.messageTargetId = `${actionId}`;
    });
  }

  backToManagementCenter(): void {
    AppNavigator.backOrReplace(this.getUIContext(), 'pages/ManagementCenter/ManagementCenter', {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }
}
