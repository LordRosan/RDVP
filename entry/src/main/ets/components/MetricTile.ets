import { AppColors } from '../styles/AppTheme';
@Component
export struct MetricTile {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop status: string = '';
  @Prop tone: string = AppColors.Primary;

  build() {
    Column({ space: 6 }) {
      Text(this.value)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tone)
        .maxLines(1)

      Text(this.label)
        .fontSize(14)
        .fontColor(AppColors.TextPrimary)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.status)
        .fontSize(12)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .padding(14)
    .height(112)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(8)
    .border({
      width: 1,
      color: AppColors.Divider
    })
  }
}
