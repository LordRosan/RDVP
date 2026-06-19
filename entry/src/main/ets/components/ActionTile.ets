import { AppColors, AppRadii } from '../styles/AppTheme';
import { MainPageAction, MainPageActionId } from '../models/app/MainPageModels';

@Component
export struct ActionTile {
  action: MainPageAction = {
    id: MainPageActionId.ArchiveCenter,
    title: '',
    tone: AppColors.Primary
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
      this.action.id === MainPageActionId.DeviceArchiveQuery ||
      this.action.id === MainPageActionId.ArchiveRecordQuery ||
      this.action.id === MainPageActionId.RecordQuery) {
      return $r('sys.symbol.text_clipboard');
    }
    if (this.action.id === MainPageActionId.DeviceArchiveCreateRequest) {
      return $r('sys.symbol.plus_circle');
    }
    if (this.action.id === MainPageActionId.OperationsCenter ||
      this.action.id === MainPageActionId.RepairReport) {
      return $r('sys.symbol.wrench_and_screwdriver');
    }
    if (this.action.id === MainPageActionId.TaskAcceptance) {
      return $r('sys.symbol.location_up');
    }
    if (this.action.id === MainPageActionId.ReinspectionReport) {
      return $r('sys.symbol.doc_text_badge_checkmark');
    }
    if (this.action.id === MainPageActionId.ManagementCenter ||
      this.action.id === MainPageActionId.DeviceArchiveReview ||
      this.action.id === MainPageActionId.OperationsReview ||
      this.action.id === MainPageActionId.ReviewRecordQuery) {
      return $r('sys.symbol.checkmark_shield');
    }
    if (this.action.id === MainPageActionId.OperationRecordQuery) {
      return $r('sys.symbol.clock');
    }
    return $r('sys.symbol.checkmark_shield');
  }

  getTone(): string {
    if (this.action.id === MainPageActionId.OperationsCenter ||
      this.action.id === MainPageActionId.DeviceVerification ||
      this.action.id === MainPageActionId.TaskAcceptance ||
      this.action.id === MainPageActionId.RepairReport ||
      this.action.id === MainPageActionId.ReinspectionReport) {
      return AppColors.Success;
    }
    if (this.action.id === MainPageActionId.ManagementCenter ||
      this.action.id === MainPageActionId.DeviceArchiveReview ||
      this.action.id === MainPageActionId.OperationsReview ||
      this.action.id === MainPageActionId.OperationRecordQuery ||
      this.action.id === MainPageActionId.ReviewRecordQuery ||
      this.action.id === MainPageActionId.RecordQuery) {
      return AppColors.Warning;
    }
    return AppColors.Primary;
  }

  getSurfaceTone(): string {
    const tone = this.getTone();
    if (tone === AppColors.Success) {
      return AppColors.SuccessSurface;
    }
    if (tone === AppColors.Warning) {
      return AppColors.WarningSurface;
    }
    return AppColors.PrimarySurface;
  }

}
