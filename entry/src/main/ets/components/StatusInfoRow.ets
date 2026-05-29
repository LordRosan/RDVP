@Component
export struct StatusInfoRow {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop tone: string = '#374151';
  @Prop valueWidth: string = '58%';
  @Prop valueMaxLines: number = 1;
  @Prop rowMinHeight: number = 54;
  @Prop verticalPadding: number = 0;

  build() {
    Row() {
      Text(this.label)
        .fontSize(15)
        .fontColor('#111827')
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.value)
        .fontSize(15)
        .fontColor(this.tone)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
        .width(this.valueWidth)
        .maxLines(this.valueMaxLines)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
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
