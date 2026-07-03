import { AppColors, AppRadii, AppTone } from '../theme/AppTheme';
import { HomeAction, HomeActionId } from '../../home/models/HomeModels';

@Component
export struct ActionTile {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  action: HomeAction = {
    id: HomeActionId.ArchiveCenter,
    title: '',
    tone: AppTone.Primary
  };

  build() {
    Row({ space: 14 }) {
      Stack() {
        SymbolGlyph(this.getIcon())
          .fontSize(24)
          .fontColor([this.getTone()])
      }
      .width(48)
      .height(48)
      .borderRadius(18)
      .backgroundColor(this.getSurfaceTone())

      Column({ space: 4 }) {
        Text(this.action.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

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

  getIcon(): Resource {
    if (this.action.id === HomeActionId.ArchiveCenter ||
      this.action.id === HomeActionId.DeviceArchiveQuery) {
      return $r('sys.symbol.text_clipboard');
    }
    if (this.action.id === HomeActionId.DeviceArchiveCreateRequest) {
      return $r('sys.symbol.plus_circle');
    }
    if (this.action.id === HomeActionId.OperationsCenter ||
      this.action.id === HomeActionId.RepairAndReinspection ||
      this.action.id === HomeActionId.OperationsLogQuery) {
      return $r('sys.symbol.wrench_and_screwdriver');
    }
    if (this.action.id === HomeActionId.TaskAcceptance) {
      return $r('sys.symbol.location_up');
    }
    if (this.action.id === HomeActionId.ReviewCenter ||
      this.action.id === HomeActionId.DeviceArchiveReview ||
      this.action.id === HomeActionId.OperationsReview) {
      return $r('sys.symbol.checkmark_shield');
    }
    if (this.action.id === HomeActionId.LogCenter) {
      return $r('sys.symbol.clock');
    }
    if (this.action.id === HomeActionId.ArchiveLogQuery) {
      return $r('sys.symbol.text_clipboard');
    }
    return $r('sys.symbol.checkmark_shield');
  }

  getTone(): string {
    return AppColors.colorForTone(this.getSemanticTone());
  }

  getSemanticTone(): AppTone {
    return this.action.tone;
  }

  getSurfaceTone(): string {
    return AppColors.surfaceForTone(this.getSemanticTone());
  }
}
