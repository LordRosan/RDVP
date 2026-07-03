import { AppColors, AppRadii, AppTone } from '../theme/AppTheme';
import { UiFeedbackTone } from '../models/UiFeedbackModels';
import { UiFeedbackService } from '../services/UiFeedbackService';

@Component
export struct InlineMessageSurface {
  @Prop message: string = '';
  @Prop tone: string = UiFeedbackTone.Danger;

  build() {
    if (this.message.length > 0) {
      Row({ space: 8 }) {
        SymbolGlyph(this.getSymbol())
          .fontSize(17)
          .fontColor([this.getTextTone()])

        Text(UiFeedbackService.sanitize(this.message))
          .fontSize(13)
          .fontColor(this.getTextTone())
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
    return AppColors.surfaceForTone(this.getAppTone());
  }

  getSymbol(): Resource {
    const tone = this.getSemanticTone();
    if (tone === UiFeedbackTone.Success) {
      return $r('sys.symbol.checkmark_circle');
    }
    if (tone === UiFeedbackTone.Warning) {
      return $r('sys.symbol.exclamationmark_triangle');
    }
    return $r('sys.symbol.exclamationmark_circle');
  }

  getTextTone(): string {
    return AppColors.colorForTone(this.getAppTone());
  }

  getAppTone(): AppTone {
    const tone = this.getSemanticTone();
    if (tone === UiFeedbackTone.Success) {
      return AppTone.Success;
    }
    if (tone === UiFeedbackTone.Warning) {
      return AppTone.Warning;
    }
    if (tone === UiFeedbackTone.Info) {
      return AppTone.Primary;
    }
    return AppTone.Danger;
  }

  getSemanticTone(): UiFeedbackTone {
    if (this.tone === UiFeedbackTone.Success) {
      return UiFeedbackTone.Success;
    }
    if (this.tone === UiFeedbackTone.Warning) {
      return UiFeedbackTone.Warning;
    }
    if (this.tone === UiFeedbackTone.Info) {
      return UiFeedbackTone.Info;
    }
    return UiFeedbackTone.Danger;
  }
}
