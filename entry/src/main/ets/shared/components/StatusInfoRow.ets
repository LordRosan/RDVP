import { AppColors } from '../theme/AppTheme';
@Component
export struct StatusInfoRow {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop tone: string = AppColors.TextSecondary;
  @Prop valueWidth: string = '58%';
  @Prop valueMaxLines: number = 1;
  @Prop valueTextAlign: TextAlign = TextAlign.End;
  @Prop valueLeadingPadding: number = 0;
  @Prop rowMinHeight: number = 54;
  @Prop verticalPadding: number = 0;

  build() {
    Row() {
      Text(this.label)
        .fontSize(15)
        .fontColor(AppColors.TextPrimary)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.value)
        .fontSize(15)
        .fontColor(this.tone)
        .fontWeight(FontWeight.Medium)
        .textAlign(this.valueTextAlign)
        .width(this.valueWidth)
        .maxLines(this.valueMaxLines)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: this.valueLeadingPadding })
    }
    .constraintSize({ minHeight: this.rowMinHeight })
    .padding({
      left: 18,
      right: 18,
      top: this.verticalPadding,
      bottom: this.verticalPadding
    })
    .width('100%')
  }
}
