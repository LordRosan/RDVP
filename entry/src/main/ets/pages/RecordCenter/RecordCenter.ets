import { AppColors } from '../../styles/AppTheme';
import { ActionTile } from '../../components/ActionTile';
import { WorkbenchActionId } from '../../models/WorkbenchModels';

@Entry
@Component
struct RecordCenter {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State selectedTab: string = 'archive';

  build() {
    Column() {
      this.PageTitleBar()

      Scroll() {
        Column({ space: 18 }) {
          this.ModeHeader()
          this.TabSelector()
          this.ContentArea()
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
      .layoutWeight(1)
      .width('100%')
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
      .border({ width: 1, color: AppColors.Divider })
      .onClick(() => {
        this.backToManagementCenter();
      })
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 24, right: 24 })
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  ModeHeader() {
    Text('记录中心')
      .fontSize(34)
      .fontWeight(FontWeight.Bold)
      .fontColor(AppColors.TextPrimary)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
      .alignSelf(ItemAlign.Start)
      .padding({ top: 0, bottom: 2 })
  }

  @Builder
  TabSelector() {
    Row({ space: 10 }) {
      this.TabChip('档案记录', 'archive')
      this.TabChip('运维记录', 'operations')
      this.TabChip('审核记录', 'review')
    }
    .width('100%')
  }

  @Builder
  TabChip(label: string, tabId: string) {
    Button(label)
      .fontSize(14)
      .fontWeight(this.selectedTab === tabId ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.selectedTab === tabId ? AppColors.Primary : AppColors.TextSecondary)
      .backgroundColor(this.selectedTab === tabId ? AppColors.PrimarySurface : AppColors.FieldBackground)
      .borderRadius(20)
      .padding({ left: 18, right: 18, top: 9, bottom: 9 })
      .border({
        width: 1,
        color: this.selectedTab === tabId ? AppColors.Primary : AppColors.Divider
      })
      .onClick(() => {
        this.selectedTab = tabId;
      })
  }

  @Builder
  ContentArea() {
    if (this.selectedTab === 'archive') {
      this.ArchiveRecordView()
    } else if (this.selectedTab === 'operations') {
      this.OperationsRecordView()
    } else {
      this.ReviewRecordView()
    }
  }

  @Builder
  ArchiveRecordView() {
    Column({ space: 12 }) {
      Row() {
        Text('档案记录')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .layoutWeight(1)

        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(16)
              .fontColor([AppColors.Primary])
            Text('查看全部')
              .fontSize(13)
              .fontColor(AppColors.Primary)
              .maxLines(1)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .backgroundColor(AppColors.PrimarySurface)
        .onClick(() => {
          this.openSubPage('pages/RecordCenter/ArchiveRecord');
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .padding(18)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
  }

  @Builder
  OperationsRecordView() {
    Column({ space: 12 }) {
      Row() {
        Text('运维记录')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .layoutWeight(1)

        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(16)
              .fontColor([AppColors.Primary])
            Text('查看全部')
              .fontSize(13)
              .fontColor(AppColors.Primary)
              .maxLines(1)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .backgroundColor(AppColors.PrimarySurface)
        .onClick(() => {
          this.openSubPage('pages/RecordCenter/OperationsRecord');
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .padding(18)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
  }

  @Builder
  ReviewRecordView() {
    Column({ space: 12 }) {
      Row() {
        Text('审核记录')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .layoutWeight(1)

        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(16)
              .fontColor([AppColors.Primary])
            Text('查看全部')
              .fontSize(13)
              .fontColor(AppColors.Primary)
              .maxLines(1)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .backgroundColor(AppColors.PrimarySurface)
        .onClick(() => {
          this.openSubPage('pages/RecordCenter/ReviewRecord');
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .padding(18)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
  }

  openSubPage(url: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }

  backToManagementCenter(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/Workbench' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
