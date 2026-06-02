import { AppColors } from '../styles/AppTheme';
import { WorkbenchAction, WorkbenchActionId } from '../models/WorkbenchModels';

@Component
export struct ActionTile {
  action: WorkbenchAction = {
    id: WorkbenchActionId.ArchiveCenter,
    title: '',
    summary: '',
    tone: AppColors.Primary
  };

  build() {
    Row({ space: 12 }) {
      Stack() {
        this.ActionIcon()
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor(this.action.tone)

      Column({ space: 5 }) {
        Text(this.action.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.action.summary)
          .fontSize(12)
          .fontColor(AppColors.TextSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .alignItems(VerticalAlign.Center)
    .padding(14)
    .height(82)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(8)
    .border({
      width: 1,
      color: AppColors.Divider
    })
  }

  @Builder
  ActionIcon() {
    if (this.action.id === WorkbenchActionId.ArchiveCenter) {
      SymbolGlyph($r('sys.symbol.text_clipboard'))
        .fontSize(23)
        .fontColor([AppColors.Surface])
    } else if (this.action.id === WorkbenchActionId.OperationsCenter) {
      SymbolGlyph($r('sys.symbol.wrench_and_screwdriver'))
        .fontSize(23)
        .fontColor([AppColors.Surface])
    } else if (this.action.id === WorkbenchActionId.ManagementCenter) {
      SymbolGlyph($r('sys.symbol.checkmark_shield'))
        .fontSize(23)
        .fontColor([AppColors.Surface])
    } else if (this.action.id === WorkbenchActionId.DeviceQuery) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(22)
        .fontColor([AppColors.Surface])
    } else if (this.action.id === WorkbenchActionId.DeviceArchiveCreate) {
      SymbolGlyph($r('sys.symbol.plus_circle'))
        .fontSize(23)
        .fontColor([AppColors.Surface])
    } else if (this.action.id === WorkbenchActionId.DeviceVerification) {
      SymbolGlyph($r('sys.symbol.checkmark_shield'))
        .fontSize(23)
        .fontColor([AppColors.Surface])
    } else if (this.action.id === WorkbenchActionId.FaultReport) {
      SymbolGlyph($r('sys.symbol.exclamationmark_message'))
        .fontSize(23)
        .fontColor([AppColors.Surface])
    } else if (this.action.id === WorkbenchActionId.AvailableRepairTask) {
      SymbolGlyph($r('sys.symbol.location_up'))
        .fontSize(23)
        .fontColor([AppColors.Surface])
    } else if (this.action.id === WorkbenchActionId.MyRepairTask) {
      SymbolGlyph($r('sys.symbol.wrench_and_screwdriver'))
        .fontSize(23)
        .fontColor([AppColors.Surface])
    } else if (this.action.id === WorkbenchActionId.ReinspectionTask) {
      SymbolGlyph($r('sys.symbol.doc_text_badge_checkmark'))
        .fontSize(23)
        .fontColor([AppColors.Surface])
    } else if (this.action.id === WorkbenchActionId.DeviceChangeReview) {
      SymbolGlyph($r('sys.symbol.checkmark_shield'))
        .fontSize(23)
        .fontColor([AppColors.Surface])
    } else {
      SymbolGlyph($r('sys.symbol.text_clipboard'))
        .fontSize(23)
        .fontColor([AppColors.Surface])
    }
  }
}
