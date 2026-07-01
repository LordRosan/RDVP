import { ActionTile } from '../../components/ActionTile';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { MainPageAction, MainPageActionId } from '../../models/app/MainPageModels';
import { LogCenterPermissions, PermissionCode } from '../../models/identity/PermissionModels';
import { UiFeedbackTone } from '../../models/common/UiFeedbackModels';
import { MainPageService } from '../../services/app/MainPageService';
import { UiFeedbackService } from '../../services/common/UiFeedbackService';
import { SessionStore } from '../../stores/SessionStore';
import { AppColors, AppSpacing } from '../../styles/AppTheme';
import { AppNavigator } from '../../utils/AppNavigator';
import { AuthGuard } from '../../utils/AuthGuard';

@Entry
@Component
struct LogCenter {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State actions: MainPageAction[] = MainPageService.getLogCenterActions();
  @State message: string = '';
  @State messageTargetId: string = '';

  aboutToAppear(): void {
    if (!AuthGuard.requireAnyPermission(this.getUIContext(), LogCenterPermissions)) {
      return;
    }

    this.refreshCenterState();
  }

  onPageShow(): void {
    if (AuthGuard.requireAnyPermission(this.getUIContext(), LogCenterPermissions)) {
      this.refreshCenterState();
    }
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: AppSpacing.Section }) {
          this.Header()
          this.PermissionSection()
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
    this.backToMainPage();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToMainPage();
      }
    })
  }

  @Builder
  Header() {
    Column({ space: 5 }) {
      Text('日志中心')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Text('Log Center')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({
      left: 0,
      right: 0,
      top: 12,
      bottom: 6
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  PermissionSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '功能权限',
        subtitle: ''
      })

      Column({ space: 16 }) {
        Grid() {
          GridItem() {
            this.PermissionCell('档案操作日志', this.canQueryArchiveOperationLog())
          }

          GridItem() {
            this.PermissionCell('档案审核日志', this.canQueryArchiveReviewLog())
          }

          GridItem() {
            this.PermissionCell('运维操作日志', this.canQueryOperationsOperationLog())
          }

          GridItem() {
            this.PermissionCell('运维审核日志', this.canQueryOperationsReviewLog())
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
        title: '业务功能',
        subtitle: ''
      })

      Column({ space: 10 }) {
        ForEach(this.actions, (item: MainPageAction) => {
          Column({ space: 8 }) {
            if (this.messageTargetId === `${item.id}` && this.message.length > 0) {
              InlineMessageSurface({
                message: this.message,
                tone: UiFeedbackTone.Danger
              })
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

  refreshCenterState(): void {
    this.actions = MainPageService.getLogCenterActions();
  }

  canQueryArchiveOperationLog(): boolean {
    return SessionStore.hasPermission(PermissionCode.LogCenterArchiveOperationLogQuery);
  }

  canQueryArchiveReviewLog(): boolean {
    return SessionStore.hasPermission(PermissionCode.LogCenterArchiveReviewLogQuery);
  }

  canQueryOperationsOperationLog(): boolean {
    return SessionStore.hasPermission(PermissionCode.LogCenterOperationsOperationLogQuery);
  }

  canQueryOperationsReviewLog(): boolean {
    return SessionStore.hasPermission(PermissionCode.LogCenterOperationsReviewLogQuery);
  }

  openFeature(action: MainPageAction): void {
    this.message = '';
    this.messageTargetId = '';
    if (action.id === MainPageActionId.ArchiveLogQuery) {
      this.openPage('pages/LogCenter/ArchiveLogQuery', UiFeedbackService.operationUnavailable('档案日志'));
      return;
    }

    if (action.id === MainPageActionId.OperationsLogQuery) {
      this.openPage('pages/LogCenter/OperationsLogQuery', UiFeedbackService.operationUnavailable('运维日志'));
      return;
    }

    this.message = UiFeedbackService.operationUnavailable('操作');
    this.messageTargetId = `${action.id}`;
  }

  openPage(url: string, errorMessage: string): void {
    AppNavigator.push(this.getUIContext(), url, () => {
      this.message = errorMessage;
      this.messageTargetId = this.resolveActionIdByUrl(url);
    });
  }

  resolveActionIdByUrl(url: string): string {
    if (url === 'pages/LogCenter/ArchiveLogQuery') {
      return `${MainPageActionId.ArchiveLogQuery}`;
    }

    if (url === 'pages/LogCenter/OperationsLogQuery') {
      return `${MainPageActionId.OperationsLogQuery}`;
    }

    return '';
  }

  backToMainPage(): void {
    AppNavigator.replaceToMainPage(this.getUIContext(), () => {
      AppNavigator.showNavigationUnavailableToast(this.getUIContext());
    });
  }
}
