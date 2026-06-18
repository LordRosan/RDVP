import { AppColors } from '../styles/AppTheme';

@Component
export struct CenterTitleBar {
  title: string = '';
  action: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(22)
          .fontColor([AppColors.TextPrimary])
      }
      .width(44)
      .height(44)
      .backgroundColor(AppColors.SurfaceRaised)
      .border({
        width: 1,
        color: AppColors.Divider
      })
      .onClick(() => {
        this.action();
      })

      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height(60)
    .padding({
      left: 20,
      right: 20
    })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppColors.PageBackground)
  }
}
