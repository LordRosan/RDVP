import { AppColors, AppRadii } from '../styles/AppTheme';

@Component
export struct AccountActionTile {
  label: string = '';
  icon: Resource = $r('sys.symbol.gearshape');
  tone: string = AppColors.Primary;

  build() {
    Row({ space: 14 }) {
      Stack() {
        SymbolGlyph(this.icon)
          .fontSize(24)
          .fontColor([this.tone])
      }
      .width(48)
      .height(48)
      .borderRadius(18)
      .backgroundColor(this.getToneSurface())

      Text(this.label)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(17)
        .fontColor([AppColors.TextTertiary])
    }
    .width('100%')
    .height(74)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: 16,
      right: 14
    })
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({
      width: 1,
      color: AppColors.Divider
    })
  }

  getToneSurface(): string {
    if (this.tone === AppColors.Danger) {
      return AppColors.DangerSurface;
    }

    return AppColors.PrimarySurface;
  }
}
