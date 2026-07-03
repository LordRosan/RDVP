import { AppColors, AppRadii } from '../theme/AppTheme';

@Component
export struct SummaryPanel {
  title: string = '';
  caption: string = '';

  @BuilderParam content: () => void = this.EmptyContent;

  build() {
    Column({ space: 14 }) {
      Column({ space: 4 }) {
        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.caption.length > 0) {
          Text(this.caption)
            .fontSize(13)
            .fontColor(AppColors.TextSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.content()
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 16,
      bottom: 16
    })
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadii.Large)
    .border({
      width: 1,
      color: AppColors.Divider
    })
  }

  @Builder
  EmptyContent() {
  }
}
