import { AppColors, AppRadii } from '../styles/AppTheme';
import { UiFeedbackService } from '../services/common/UiFeedbackService';

@Component
export struct InlineMessageSurface {
  @Prop message: string = '';
  @Prop tone: string = AppColors.Danger;

  build() {
    if (this.message.length > 0) {
      Row({ space: 8 }) {
        SymbolGlyph(this.getSymbol())
          .fontSize(17)
          .fontColor([this.tone])

        Text(UiFeedbackService.sanitize(this.message))
          .fontSize(13)
          .fontColor(this.tone)
          .lineHeight(18)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({
        left: 12,
        right: 12,
        top: 10,
        bottom: 10
      })
      .alignItems(VerticalAlign.Top)
      .backgroundColor(this.getSurfaceTone())
      .borderRadius(AppRadii.Small)
    }
  }

  getSurfaceTone(): string {
    if (this.tone === AppColors.Success) {
      return AppColors.SuccessSurface;
    }
    if (this.tone === AppColors.Warning) {
      return AppColors.WarningSurface;
    }
    if (this.tone === AppColors.Primary) {
      return AppColors.PrimarySurface;
    }
    return AppColors.DangerSurface;
  }

  getSymbol(): Resource {
    if (this.tone === AppColors.Success) {
      return $r('sys.symbol.checkmark_circle');
    }
    if (this.tone === AppColors.Warning) {
      return $r('sys.symbol.exclamationmark_triangle');
    }
    return $r('sys.symbol.exclamationmark_circle');
  }
}
