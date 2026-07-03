import { AppColors, AppSpacing } from '../../shared/theme/AppTheme';
import { CenterTitleBar } from '../../shared/components/CenterTitleBar';
import { RepairReportTabContent } from '../components/RepairReportTabContent';
import { ReinspectionReportTabContent } from '../components/ReinspectionReportTabContent';
import { PermissionCode } from '../../user/models/PermissionModels';
import { SessionStore } from '../../user/stores/SessionStore';
import { AuthGuard } from '../../shared/security/AuthGuard';
import { AppNavigator } from '../../shared/navigation/AppNavigator';

enum RepairAndReinspectionTab {
  Repair = 'REPAIR',
  Reinspection = 'REINSPECTION'
}

@Entry
@Component
struct RepairAndReinspectionPage {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State currentTab: RepairAndReinspectionTab = RepairAndReinspectionTab.Repair;
  @State currentTabIndex: number = 0;

  aboutToAppear(): void {
    if (!AuthGuard.requireAnyPermission(this.getUIContext(), [
      PermissionCode.OperationsCenterRepairReportSubmit,
      PermissionCode.OperationsCenterReinspectionReportSubmit
    ])) {
      return;
    }

    if (!this.canOpenRepairReport() && !this.canOpenReinspectionReport()) {
      AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      this.backToOperationsCenter();
      return;
    }

    this.ensureAvailableTab();
  }

  build() {
    Tabs({
      barPosition: BarPosition.End,
      index: this.currentTabIndex
    }) {
      TabContent() {
        this.TabContentView(RepairAndReinspectionTab.Repair)
      }
      .tabBar(this.TabBarItem('维修任务', $r('sys.symbol.wrench_and_screwdriver'),
        RepairAndReinspectionTab.Repair, this.canOpenRepairReport()))

      TabContent() {
        this.TabContentView(RepairAndReinspectionTab.Reinspection)
      }
      .tabBar(this.TabBarItem('复检任务', $r('sys.symbol.doc_text_badge_checkmark'),
        RepairAndReinspectionTab.Reinspection, this.canOpenReinspectionReport()))
    }
    .barMode(BarMode.Fixed)
    .barHeight(78)
    .scrollable(false)
    .onChange((index: number) => {
      this.switchTab(this.getTabFromIndex(index));
    })
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    this.backToOperationsCenter();
    return true;
  }

  @Builder
  TabContentView(tab: RepairAndReinspectionTab) {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column() {
          if (tab === RepairAndReinspectionTab.Repair && this.canOpenRepairReport()) {
            RepairReportTabContent()
          } else if (tab === RepairAndReinspectionTab.Reinspection && this.canOpenReinspectionReport()) {
            ReinspectionReportTabContent()
          } else {
            this.UnavailableTab()
          }
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
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToOperationsCenter();
      }
    })
  }

  @Builder
  TabBarItem(label: string, icon: Resource, tab: RepairAndReinspectionTab, enabled: boolean) {
    Column({ space: 4 }) {
      SymbolGlyph(icon)
        .fontSize(25)
        .fontColor([this.getTabIconColor(tab, enabled)])

      Text(label)
        .fontSize(12)
        .fontWeight(this.currentTab === tab ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.getTabLabelColor(tab, enabled))
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(62)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .opacity(enabled ? 1 : 0.45)
    .enabled(enabled)
  }

  @Builder
  UnavailableTab() {
    Column({ space: 10 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.lock'))
          .fontSize(36)
          .fontColor([AppColors.Warning])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.WarningSurface)

      Text('暂无权限')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
    }
    .width('100%')
    .padding({ top: 48, bottom: 48 })
    .alignItems(HorizontalAlign.Center)
  }

  switchTab(tab: RepairAndReinspectionTab): void {
    if (!this.canOpenTab(tab)) {
      this.currentTabIndex = this.getTabIndex(this.currentTab);
      return;
    }

    this.currentTab = tab;
    this.currentTabIndex = this.getTabIndex(tab);
  }

  ensureAvailableTab(): void {
    if (this.canOpenTab(this.currentTab)) {
      this.currentTabIndex = this.getTabIndex(this.currentTab);
      return;
    }

    this.currentTab = this.canOpenRepairReport() ? RepairAndReinspectionTab.Repair :
      RepairAndReinspectionTab.Reinspection;
    this.currentTabIndex = this.getTabIndex(this.currentTab);
  }

  canOpenTab(tab: RepairAndReinspectionTab): boolean {
    return tab === RepairAndReinspectionTab.Repair ? this.canOpenRepairReport() : this.canOpenReinspectionReport();
  }

  canOpenRepairReport(): boolean {
    return SessionStore.hasPermission(PermissionCode.OperationsCenterRepairReportSubmit);
  }

  canOpenReinspectionReport(): boolean {
    return SessionStore.hasAllPermissions([
      PermissionCode.OperationsCenterReinspectionTaskAccept,
      PermissionCode.OperationsCenterReinspectionReportSubmit
    ]);
  }

  getTabIndex(tab: RepairAndReinspectionTab): number {
    return tab === RepairAndReinspectionTab.Reinspection ? 1 : 0;
  }

  getTabFromIndex(index: number): RepairAndReinspectionTab {
    return index === 1 ? RepairAndReinspectionTab.Reinspection : RepairAndReinspectionTab.Repair;
  }

  getTabIconColor(tab: RepairAndReinspectionTab, enabled: boolean): string {
    if (!enabled) {
      return AppColors.Disabled;
    }

    return this.currentTab === tab ? AppColors.Success : AppColors.TextTertiary;
  }

  getTabLabelColor(tab: RepairAndReinspectionTab, enabled: boolean): string {
    if (!enabled) {
      return AppColors.Disabled;
    }

    return this.currentTab === tab ? AppColors.Success : AppColors.TextSecondary;
  }

  backToOperationsCenter(): void {
    AppNavigator.backOrReplace(this.getUIContext(), 'operations/pages/OperationsCenterPage', {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }
}
