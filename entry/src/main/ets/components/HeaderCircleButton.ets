import { AppColors } from '../styles/AppTheme';

@Component
export struct HeaderCircleButton {
  icon: Resource = $r('sys.symbol.gearshape');
  iconSize: number = 31;
  action: () => void = () => {};

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(this.icon)
        .fontSize(this.iconSize)
        .fontColor([AppColors.TextPrimary])
    }
    .width(52)
    .height(52)
    .backgroundColor(AppColors.SurfaceRaised)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .onClick(() => {
      this.action();
    })
  }
}
