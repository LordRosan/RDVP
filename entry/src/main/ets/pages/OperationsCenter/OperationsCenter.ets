import { AppColors, AppSpacing } from '../../styles/AppTheme';
import { ActionTile } from '../../components/ActionTile';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { HeroSurface } from '../../components/HeroSurface';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { SummaryPanel } from '../../components/SummaryPanel';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { OperationsCenterPermissions, PermissionCode } from '../../models/identity/PermissionModels';
import { MainPageAction, MainPageActionId } from '../../models/app/MainPageModels';
import { MainPageService } from '../../services/app/MainPageService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';
import { PermissionTextFormatter } from '../../utils/PermissionTextFormatter';

@Entry
@Component
struct OperationsCenter {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State actions: MainPageAction[] = MainPageService.getOperationsCenterActions();
  @State message: string = '';
  @State messageTargetId: string = '';

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
      title: '运维中心',
      action: () => {
        this.backToMainPage();
      }
    })
  }

  @Builder
  PageHero() {
    HeroSurface({
      eyebrow: 'Operations command',
      title: '运维中心',
      subtitle: '围绕现场核验、任务接取、维修上报和复检闭环组织工作。',
      icon: $r('sys.symbol.wrench_and_screwdriver'),
      tone: AppColors.Success
    })
  }

  @Builder
  OverviewPanel() {
    SummaryPanel({
      title: '中心概览',
      caption: '当前账号可处理的运维能力。'
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
        subtitle: '选择任务或记录入口继续处理。'
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
    this.actions = MainPageService.getOperationsCenterActions();
  }

  getPermissionSummaryText(): string {
    const parts: string[] = [];
    if (SessionStore.hasPermission(PermissionCode.OperationsCenterDeviceVerificationSubmit)) {
      parts.push('可核验');
    }
    if (SessionStore.hasPermission(PermissionCode.OperationsCenterRepairTaskAccept)) {
      parts.push('可接取');
    }
    if (SessionStore.hasPermission(PermissionCode.OperationsCenterRepairReportSubmit)) {
      parts.push('可维修');
    }
    if (SessionStore.hasPermission(PermissionCode.OperationsCenterReinspectionReportSubmit)) {
      parts.push('可复检');
    }
    return PermissionTextFormatter.formatTwoPerLine(parts);
  }

  openFeature(action: MainPageAction): void {
    this.message = '';
    this.messageTargetId = '';
    if (action.id === MainPageActionId.DeviceVerification) {
      this.openPage('pages/OperationsCenter/DeviceVerification', '核验与报修不可用');
      return;
    }

    if (action.id === MainPageActionId.TaskAcceptance) {
      this.openPage('pages/OperationsCenter/TaskAcceptance', '任务接取不可用');
      return;
    }

    if (action.id === MainPageActionId.RepairReport) {
      this.openPage('pages/OperationsCenter/RepairReport', '维修任务不可用');
      return;
    }

    if (action.id === MainPageActionId.ReinspectionReport) {
      this.openPage('pages/OperationsCenter/ReinspectionReport', '复检任务不可用');
      return;
    }

    if (action.id === MainPageActionId.OperationRecordQuery) {
      this.openPage('pages/ManagementCenter/RecordQuery/OperationRecordQuery', '运维记录不可用');
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
    if (url === 'pages/OperationsCenter/DeviceVerification') {
      return `${MainPageActionId.DeviceVerification}`;
    }

    if (url === 'pages/OperationsCenter/TaskAcceptance') {
      return `${MainPageActionId.TaskAcceptance}`;
    }

    if (url === 'pages/OperationsCenter/RepairReport') {
      return `${MainPageActionId.RepairReport}`;
    }

    if (url === 'pages/OperationsCenter/ReinspectionReport') {
      return `${MainPageActionId.ReinspectionReport}`;
    }

    if (url === 'pages/ManagementCenter/RecordQuery/OperationRecordQuery') {
      return `${MainPageActionId.OperationRecordQuery}`;
    }

    return '';
  }

  backToMainPage(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/MainPage' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}


