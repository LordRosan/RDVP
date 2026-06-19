import { AppColors, AppSpacing } from '../../styles/AppTheme';
import { ActionTile } from '../../components/ActionTile';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { HeroSurface } from '../../components/HeroSurface';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { SummaryPanel } from '../../components/SummaryPanel';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { ManagementCenterPermissions, PermissionCode } from '../../models/identity/PermissionModels';
import { MainPageAction, MainPageActionId } from '../../models/app/MainPageModels';
import { MainPageService } from '../../services/app/MainPageService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';
import { MainPageNavigator } from '../../utils/MainPageNavigator';
import { PermissionTextFormatter } from '../../utils/PermissionTextFormatter';

@Entry
@Component
struct ManagementCenter {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State actions: MainPageAction[] = MainPageService.getManagementCenterActions();
  @State message: string = '';
  @State messageTargetId: string = '';

  aboutToAppear(): void {
    if (!AuthGuard.requireAnyPermission(this.getUIContext(), ManagementCenterPermissions)) {
      return;
    }

    this.refreshCenterState();
  }

  onPageShow(): void {
    if (AuthGuard.requireAnyPermission(this.getUIContext(), ManagementCenterPermissions)) {
      this.refreshCenterState();
    }
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: AppSpacing.Section }) {
          this.PageHero()
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
    this.backToMainPage();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      title: '管理中心',
      action: () => {
        this.backToMainPage();
      }
    })
  }

  @Builder
  PageHero() {
    HeroSurface({
      eyebrow: 'Management command',
      title: '管理中心',
      subtitle: '聚合档案审核、记录查询和业务流转追溯能力。',
      icon: $r('sys.symbol.checkmark_shield'),
      tone: AppColors.Warning
    })
  }

  @Builder
  OverviewPanel() {
    SummaryPanel({
      title: '中心概览',
      caption: '当前账号可执行的管理能力。'
    }) {
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
      }
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .borderRadius(18)
    }
  }

  @Builder
  ActionSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '功能入口',
        subtitle: '进入审核处理或记录检索。'
      })

      Column({ space: 10 }) {
        ForEach(this.actions, (item: MainPageAction) => {
          Column({ space: 8 }) {
            if (this.messageTargetId === `${item.id}` && this.message.length > 0) {
              InlineMessageSurface({
                message: this.message,
                tone: AppColors.Danger
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

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      InlineMessageSurface({
        message: this.message,
        tone: AppColors.Danger
      })
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
    this.actions = MainPageService.getManagementCenterActions();
  }

  getPermissionSummaryText(): string {
    const parts: string[] = [];
    if (SessionStore.hasPermission(PermissionCode.ManagementCenterDeviceArchiveRequestReview)) {
      parts.push('档案审核');
    }
    if (SessionStore.hasPermission(PermissionCode.ManagementCenterOperationsReview)) {
      parts.push('运维审核');
    }
    if (SessionStore.hasPermission(PermissionCode.ManagementCenterArchiveRecordQuery)) {
      parts.push('档案记录');
    }
    if (SessionStore.hasPermission(PermissionCode.ManagementCenterOperationRecordQuery)) {
      parts.push('运维记录');
    }
    if (SessionStore.hasPermission(PermissionCode.ManagementCenterReviewRecordQuery)) {
      parts.push('审核记录');
    }

    return PermissionTextFormatter.formatTwoPerLine(parts);
  }

  openFeature(action: MainPageAction): void {
    this.message = '';
    this.messageTargetId = '';
    if (action.id === MainPageActionId.DeviceArchiveReview) {
      this.openPage('pages/ManagementCenter/DeviceArchiveReview', '档案审核不可用');
      return;
    }

    if (action.id === MainPageActionId.OperationsReview) {
      this.message = '运维审核功能后续开放';
      this.messageTargetId = `${action.id}`;
      return;
    }

    if (action.id === MainPageActionId.RecordQuery) {
      this.openPage('pages/ManagementCenter/RecordQuery/RecordQuery', '记录查询不可用');
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
    if (url === 'pages/ManagementCenter/DeviceArchiveReview') {
      return `${MainPageActionId.DeviceArchiveReview}`;
    }

    if (url === 'pages/ManagementCenter/RecordQuery/RecordQuery') {
      return `${MainPageActionId.RecordQuery}`;
    }

    return '';
  }

  backToMainPage(): void {
    if (!MainPageNavigator.replaceToMainPage(this.getUIContext())) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}


