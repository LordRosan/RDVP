import { AppColors, AppRadii } from '../styles/AppTheme';

@Component
export struct MetricTile {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop status: string = '';
  @Prop tone: string = AppColors.Primary;

  build() {
    Column({ space: 9 }) {
      Row() {
        Text(this.value)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tone)
          .maxLines(1)
          .layoutWeight(1)

        Stack()
          .width(9)
          .height(9)
          .borderRadius(5)
          .backgroundColor(this.tone)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 2 }) {
        Text(this.label)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.status)
          .fontSize(12)
          .fontColor(AppColors.TextSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(104)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: 16,
      right: 16,
      top: 14,
      bottom: 14
    })
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({
      width: 1,
      color: AppColors.Divider
    })
  }
}
