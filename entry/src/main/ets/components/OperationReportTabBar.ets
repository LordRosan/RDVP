import { AppColors, AppSpacing } from '../styles/AppTheme';

export enum OperationReportTab {
  Repair = 'REPAIR',
  Reinspection = 'REINSPECTION'
}

export const OperationReportBottomContentPadding: number = 112;
export const OperationReportBottomTabHeight: number = 78;

@Component
export struct OperationReportTabBar {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  currentTab: OperationReportTab = OperationReportTab.Repair;
  repairEnabled: boolean = true;
  reinspectionEnabled: boolean = true;
  onRepairClick: () => void = () => {
  };
  onReinspectionClick: () => void = () => {
  };

  build() {
    Row() {
      this.TabItem(
        '维修任务',
        $r('sys.symbol.wrench_and_screwdriver'),
        OperationReportTab.Repair,
        this.repairEnabled,
        () => {
          this.onRepairClick();
        })

      this.TabItem(
        '复检任务',
        $r('sys.symbol.doc_text_badge_checkmark'),
        OperationReportTab.Reinspection,
        this.reinspectionEnabled,
        () => {
          this.onReinspectionClick();
        })
    }
    .width('100%')
    .height(OperationReportBottomTabHeight)
    .padding({
      left: AppSpacing.PageX,
      right: AppSpacing.PageX,
      top: 6,
      bottom: 8
    })
    .backgroundColor(AppColors.PageBackground)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  TabItem(label: string, icon: Resource, tab: OperationReportTab, enabled: boolean, action: () => void) {
    Column({ space: 4 }) {
      SymbolGlyph(icon)
        .fontSize(25)
        .fontColor([this.getIconColor(tab, enabled)])

      Text(label)
        .fontSize(12)
        .fontWeight(this.currentTab === tab ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.getLabelColor(tab, enabled))
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(62)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .opacity(enabled ? 1 : 0.45)
    .onClick(() => {
      if (!enabled || this.currentTab === tab) {
        return;
      }

      action();
    })
  }

  getIconColor(tab: OperationReportTab, enabled: boolean): string {
    if (!enabled) {
      return AppColors.Disabled;
    }

    return this.currentTab === tab ? AppColors.Success : AppColors.TextTertiary;
  }

  getLabelColor(tab: OperationReportTab, enabled: boolean): string {
    if (!enabled) {
      return AppColors.Disabled;
    }

    return this.currentTab === tab ? AppColors.Success : AppColors.TextSecondary;
  }
}
