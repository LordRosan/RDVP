import { ActionTile } from '../../shared/components/ActionTile';
import { AppSectionTitle } from '../../shared/components/AppSectionTitle';
import { CenterTitleBar } from '../../shared/components/CenterTitleBar';
import { InlineMessageSurface } from '../../shared/components/InlineMessageSurface';
import { HomeAction, HomeActionId } from '../../home/models/HomeModels';
import { LogCenterPermissions, PermissionCode } from '../../user/models/PermissionModels';
import { UiFeedbackTone } from '../../shared/models/UiFeedbackModels';
import { HomeService } from '../../home/services/HomeService';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';
import { SessionStore } from '../../user/stores/SessionStore';
import { AppColors, AppSpacing } from '../../shared/theme/AppTheme';
import { AppNavigator } from '../../shared/navigation/AppNavigator';
import { AuthGuard } from '../../shared/security/AuthGuard';

@Entry
@Component
struct LogCenterPage {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State actions: HomeAction[] = HomeService.getLogCenterActions();
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
    this.backToHomePage();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToHomePage();
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
        ForEach(this.actions, (item: HomeAction) => {
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
        }, (item: HomeAction) => item.id)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  refreshCenterState(): void {
    this.actions = HomeService.getLogCenterActions();
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

  openFeature(action: HomeAction): void {
    this.message = '';
    this.messageTargetId = '';
    if (action.id === HomeActionId.ArchiveLogQuery) {
      this.openPage('log/pages/ArchiveLogQueryPage', UiFeedbackService.operationUnavailable('档案日志'));
      return;
    }

    if (action.id === HomeActionId.OperationsLogQuery) {
      this.openPage('log/pages/OperationsLogQueryPage', UiFeedbackService.operationUnavailable('运维日志'));
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
    if (url === 'log/pages/ArchiveLogQueryPage') {
      return `${HomeActionId.ArchiveLogQuery}`;
    }

    if (url === 'log/pages/OperationsLogQueryPage') {
      return `${HomeActionId.OperationsLogQuery}`;
    }

    return '';
  }

  backToHomePage(): void {
    AppNavigator.replaceToHomePage(this.getUIContext(), () => {
      AppNavigator.showNavigationUnavailableToast(this.getUIContext());
    });
  }
}
