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
    .width(58)
    .height(58)
    .backgroundColor(AppColors.Surface)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .onClick(() => {
      this.action();
    })
  }
}
