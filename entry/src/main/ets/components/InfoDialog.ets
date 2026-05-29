export interface InfoDialogItem {
  label: string;
  description: string;
}

export interface InfoDialogSection {
  title: string;
  items: InfoDialogItem[];
}

@CustomDialog
export struct InfoDialog {
  controller?: CustomDialogController;
  title: string = '';
  sections: InfoDialogSection[] = [];

  build() {
    Column({ space: 16 }) {
      Row() {
        Text(this.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor(['#111827'])
        }
        .width(40)
        .height(40)
        .backgroundColor('#F2F5F7')
        .onClick(() => {
          this.controller?.close();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 14 }) {
          ForEach(this.sections, (section: InfoDialogSection, sectionIndex: number) => {
            if (sectionIndex > 0) {
              Divider()
                .height(1)
                .backgroundColor('#E5E7EB')
                .margin({ top: 2, bottom: 2 })
            }

            this.SectionTitle(section.title)

            ForEach(section.items, (item: InfoDialogItem) => {
              this.InfoRow(item.label, item.description)
            }, (item: InfoDialogItem) => `${section.title}-${item.label}`)
          }, (section: InfoDialogSection) => section.title)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .constraintSize({ maxHeight: 520 })
      .scrollBar(BarState.Off)
    }
    .width('88%')
    .padding({
      left: 22,
      right: 22,
      top: 22,
      bottom: 20
    })
    .backgroundColor('#FFFFFF')
    .borderRadius(28)
    .clip(true)
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .fontColor('#111827')
      .maxLines(1)
  }

  @Builder
  InfoRow(label: string, description: string) {
    Row({ space: 8 }) {
      Text(`${label}：`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111827')
        .width(86)
        .textAlign(TextAlign.End)

      Text(description)
        .fontSize(14)
        .fontColor('#374151')
        .lineHeight(20)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}
