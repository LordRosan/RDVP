import { AppColors, AppSpacing } from '../styles/AppTheme';

export enum LogQueryTab {
  Operation = 'OPERATION',
  Review = 'REVIEW'
}

export const LogQueryBottomContentPadding: number = 112;
export const LogQueryBottomTabHeight: number = 78;

@Component
export struct LogQueryTabBar {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @Prop currentTab: LogQueryTab = LogQueryTab.Operation;
  @Prop operationEnabled: boolean = true;
  @Prop reviewEnabled: boolean = true;
  onOperationClick: () => void = () => {
  };
  onReviewClick: () => void = () => {
  };

  build() {
    Row() {
      this.TabItem(
        '操作日志',
        $r('sys.symbol.text_clipboard'),
        LogQueryTab.Operation,
        this.operationEnabled,
        () => {
          this.onOperationClick();
        })

      this.TabItem(
        '审核日志',
        $r('sys.symbol.checkmark_shield'),
        LogQueryTab.Review,
        this.reviewEnabled,
        () => {
          this.onReviewClick();
        })
    }
    .width('100%')
    .height(LogQueryBottomTabHeight)
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
  TabItem(label: string, icon: Resource, tab: LogQueryTab, enabled: boolean, action: () => void) {
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
      if (!enabled) {
        return;
      }

      action();
    })
  }

  getIconColor(tab: LogQueryTab, enabled: boolean): string {
    if (!enabled) {
      return AppColors.Disabled;
    }

    return this.currentTab === tab ? AppColors.Log : AppColors.TextTertiary;
  }

  getLabelColor(tab: LogQueryTab, enabled: boolean): string {
    if (!enabled) {
      return AppColors.Disabled;
    }

    return this.currentTab === tab ? AppColors.Log : AppColors.TextSecondary;
  }
}
