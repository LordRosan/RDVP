import { AppColors, AppRadii, AppTone } from '../styles/AppTheme';
import { MainPageAction, MainPageActionId } from '../models/app/MainPageModels';

@Component
export struct ActionTile {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  action: MainPageAction = {
    id: MainPageActionId.ArchiveCenter,
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
    if (this.action.id === MainPageActionId.ArchiveCenter ||
      this.action.id === MainPageActionId.DeviceArchiveQuery) {
      return $r('sys.symbol.text_clipboard');
    }
    if (this.action.id === MainPageActionId.DeviceArchiveCreateRequest) {
      return $r('sys.symbol.plus_circle');
    }
    if (this.action.id === MainPageActionId.OperationsCenter ||
      this.action.id === MainPageActionId.RepairAndReinspection ||
      this.action.id === MainPageActionId.OperationsLogQuery) {
      return $r('sys.symbol.wrench_and_screwdriver');
    }
    if (this.action.id === MainPageActionId.TaskAcceptance) {
      return $r('sys.symbol.location_up');
    }
    if (this.action.id === MainPageActionId.ReviewCenter ||
      this.action.id === MainPageActionId.DeviceArchiveReview ||
      this.action.id === MainPageActionId.OperationsReview) {
      return $r('sys.symbol.checkmark_shield');
    }
    if (this.action.id === MainPageActionId.LogCenter) {
      return $r('sys.symbol.clock');
    }
    if (this.action.id === MainPageActionId.ArchiveLogQuery) {
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
