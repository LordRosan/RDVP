import { AppColors, AppRadii } from '../theme/AppTheme';

@Component
export struct HeroSurface {
  eyebrow: string = '';
  title: string = '';
  subtitle: string = '';
  icon: Resource = $r('sys.symbol.checkmark_shield');
  tone: string = AppColors.Primary;

  build() {
    Column() {
      Row() {
        Column({ space: 8 }) {
          if (this.eyebrow.length > 0) {
            Text(this.eyebrow)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.tone)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          Text(this.title)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.subtitle)
            .fontSize(14)
            .fontColor(AppColors.TextSecondary)
            .lineHeight(20)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Stack() {
          SymbolGlyph(this.icon)
            .fontSize(34)
            .fontColor([AppColors.OnPrimary])
        }
        .width(62)
        .height(62)
        .borderRadius(22)
        .backgroundColor(this.tone)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding({
      left: 22,
      right: 22,
      top: 24,
      bottom: 22
    })
    .backgroundColor(AppColors.HeroSurface)
    .borderRadius(AppRadii.Hero)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .shadow({
      radius: 20,
      color: AppColors.Shadow,
      offsetX: 0,
      offsetY: 8
    })
  }
}
