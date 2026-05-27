import { WorkbenchAction, WorkbenchActionId } from '../models/WorkbenchModels';

@Component
export struct ActionTile {
  action: WorkbenchAction = {
    id: WorkbenchActionId.DeviceCodeSearch,
    title: '',
    summary: '',
    mark: '',
    tone: '#2F6FED'
  };
  active: boolean = false;

  build() {
    Row({ space: 12 }) {
      Text(this.action.mark)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .width(42)
        .height(42)
        .borderRadius(21)
        .backgroundColor(this.action.tone)

      Column({ space: 5 }) {
        Text(this.action.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.action.summary)
          .fontSize(12)
          .fontColor('#6B7280')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .alignItems(VerticalAlign.Center)
    .padding(14)
    .height(82)
    .width('100%')
    .backgroundColor(this.active ? '#EEF4FF' : '#FFFFFF')
    .borderRadius(8)
    .border({
      width: 1,
      color: this.active ? '#2F6FED' : '#E5E7EB'
    })
  }
}
