import { AppColors, AppSpacing } from '../../shared/theme/AppTheme';
import { ActionTile } from '../../shared/components/ActionTile';
import { AppSectionTitle } from '../../shared/components/AppSectionTitle';
import { CenterTitleBar } from '../../shared/components/CenterTitleBar';
import { InlineMessageSurface } from '../../shared/components/InlineMessageSurface';
import { OperationsCenterPermissions, PermissionCode } from '../../user/models/PermissionModels';
import { HomeAction, HomeActionId } from '../../home/models/HomeModels';
import { HomeService } from '../../home/services/HomeService';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';
import { SessionStore } from '../../user/stores/SessionStore';
import { AuthGuard } from '../../shared/security/AuthGuard';
import { AppNavigator } from '../../shared/navigation/AppNavigator';
import { UiFeedbackTone } from '../../shared/models/UiFeedbackModels';

@Entry
@Component
struct OperationsCenterPage {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State actions: HomeAction[] = HomeService.getOperationsCenterActions();
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
      Text('运维中心')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Text('Operations Center')
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
            this.PermissionCell('设备核验', this.canVerifyDevice())
          }

          GridItem() {
            this.PermissionCell('设备报修', this.canSubmitFaultReport())
          }

          GridItem() {
            this.PermissionCell('任务接取', this.canAcceptTask())
          }

          GridItem() {
            this.PermissionCell('维修提交', this.canSubmitRepairReport())
          }

          GridItem() {
            this.PermissionCell('复检提交', this.canSubmitReinspectionReport())
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
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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
    this.actions = HomeService.getOperationsCenterActions();
  }

  canVerifyDevice(): boolean {
    return SessionStore.hasPermission(PermissionCode.OperationsCenterDeviceVerificationSubmit);
  }

  canSubmitFaultReport(): boolean {
    return SessionStore.hasPermission(PermissionCode.OperationsCenterDeviceFaultReportSubmit);
  }

  canAcceptTask(): boolean {
    return SessionStore.hasPermission(PermissionCode.OperationsCenterRepairTaskAccept) ||
      SessionStore.hasPermission(PermissionCode.OperationsCenterReinspectionTaskAccept);
  }

  canSubmitRepairReport(): boolean {
    return SessionStore.hasPermission(PermissionCode.OperationsCenterRepairReportSubmit);
  }

  canSubmitReinspectionReport(): boolean {
    return SessionStore.hasPermission(PermissionCode.OperationsCenterReinspectionReportSubmit);
  }

  openFeature(action: HomeAction): void {
    this.message = '';
    this.messageTargetId = '';
    if (action.id === HomeActionId.VerificationAndFaultReport) {
      this.openPage(this.getVerificationAndFaultReportEntryUrl(), UiFeedbackService.operationUnavailable('核验与报修'));
      return;
    }

    if (action.id === HomeActionId.TaskAcceptance) {
      this.openPage('operations/pages/TaskAcceptancePage', UiFeedbackService.operationUnavailable('任务接取'));
      return;
    }

    if (action.id === HomeActionId.RepairAndReinspection) {
      this.openPage(this.getRepairAndReinspectionEntryUrl(), UiFeedbackService.operationUnavailable('维修与复检'));
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
    if (url === HomeService.getVerificationAndFaultReportRoute()) {
      return `${HomeActionId.VerificationAndFaultReport}`;
    }

    if (url === 'operations/pages/TaskAcceptancePage') {
      return `${HomeActionId.TaskAcceptance}`;
    }

    if (url === HomeService.getRepairAndReinspectionRoute()) {
      return `${HomeActionId.RepairAndReinspection}`;
    }

    return '';
  }

  getVerificationAndFaultReportEntryUrl(): string {
    return HomeService.getVerificationAndFaultReportRoute();
  }

  getRepairAndReinspectionEntryUrl(): string {
    return HomeService.getRepairAndReinspectionRoute();
  }

  backToHomePage(): void {
    AppNavigator.replaceToHomePage(this.getUIContext(), () => {
      AppNavigator.showNavigationUnavailableToast(this.getUIContext());
    });
  }
}


