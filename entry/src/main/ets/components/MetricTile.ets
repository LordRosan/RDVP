@Component
export struct MetricTile {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop status: string = '';
  @Prop tone: string = '#2F6FED';

  build() {
    Column({ space: 6 }) {
      Text(this.value)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tone)
        .maxLines(1)

      Text(this.label)
        .fontSize(14)
        .fontColor('#1F2933')
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.status)
        .fontSize(12)
        .fontColor('#6B7280')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .padding(14)
    .height(112)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .border({
      width: 1,
      color: '#E5E7EB'
    })
  }
}
