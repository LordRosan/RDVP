import { AppColors, AppRadii } from '../styles/AppTheme';
import { WorkbenchAction, WorkbenchActionId } from '../models/app/WorkbenchModels';

@Component
export struct ActionTile {
  action: WorkbenchAction = {
    id: WorkbenchActionId.ArchiveCenter,
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
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.getHint())
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
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
    .height(82)
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
    if (this.action.id === WorkbenchActionId.ArchiveCenter ||
      this.action.id === WorkbenchActionId.DeviceArchiveQuery ||
      this.action.id === WorkbenchActionId.ArchiveRecordQuery ||
      this.action.id === WorkbenchActionId.RecordQuery) {
      return $r('sys.symbol.text_clipboard');
    }
    if (this.action.id === WorkbenchActionId.DeviceArchiveCreateRequest) {
      return $r('sys.symbol.plus_circle');
    }
    if (this.action.id === WorkbenchActionId.OperationsCenter ||
      this.action.id === WorkbenchActionId.RepairReport) {
      return $r('sys.symbol.wrench_and_screwdriver');
    }
    if (this.action.id === WorkbenchActionId.TaskAcceptance) {
      return $r('sys.symbol.location_up');
    }
    if (this.action.id === WorkbenchActionId.ReinspectionReport) {
      return $r('sys.symbol.doc_text_badge_checkmark');
    }
    if (this.action.id === WorkbenchActionId.ManagementCenter ||
      this.action.id === WorkbenchActionId.DeviceArchiveReview ||
      this.action.id === WorkbenchActionId.ReviewRecordQuery) {
      return $r('sys.symbol.checkmark_shield');
    }
    if (this.action.id === WorkbenchActionId.OperationRecordQuery) {
      return $r('sys.symbol.clock');
    }
    return $r('sys.symbol.checkmark_shield');
  }

  getTone(): string {
    if (this.action.id === WorkbenchActionId.OperationsCenter ||
      this.action.id === WorkbenchActionId.DeviceVerification ||
      this.action.id === WorkbenchActionId.TaskAcceptance ||
      this.action.id === WorkbenchActionId.RepairReport ||
      this.action.id === WorkbenchActionId.ReinspectionReport) {
      return AppColors.Success;
    }
    if (this.action.id === WorkbenchActionId.ManagementCenter ||
      this.action.id === WorkbenchActionId.DeviceArchiveReview ||
      this.action.id === WorkbenchActionId.OperationRecordQuery ||
      this.action.id === WorkbenchActionId.ReviewRecordQuery ||
      this.action.id === WorkbenchActionId.RecordQuery) {
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

  getHint(): string {
    if (this.action.id === WorkbenchActionId.ArchiveCenter) {
      return '档案、二维码与资产可信查询';
    }
    if (this.action.id === WorkbenchActionId.OperationsCenter) {
      return '现场核验、维修和复检任务';
    }
    if (this.action.id === WorkbenchActionId.ManagementCenter) {
      return '审核流转与业务记录追溯';
    }
    if (this.action.id === WorkbenchActionId.DeviceArchiveQuery) {
      return '按设备编号或二维码定位档案';
    }
    if (this.action.id === WorkbenchActionId.DeviceArchiveCreateRequest) {
      return '提交新增设备档案申请';
    }
    if (this.action.id === WorkbenchActionId.DeviceVerification) {
      return '记录现场状态并发起报修';
    }
    if (this.action.id === WorkbenchActionId.TaskAcceptance) {
      return '查看并接取可处理任务';
    }
    if (this.action.id === WorkbenchActionId.RepairReport) {
      return '提交维修过程和结果';
    }
    if (this.action.id === WorkbenchActionId.ReinspectionReport) {
      return '完成重大故障复检闭环';
    }
    if (this.action.id === WorkbenchActionId.DeviceArchiveReview) {
      return '审核档案新增、修改和删除';
    }
    if (this.action.id === WorkbenchActionId.OperationRecordQuery) {
      return '查看运维处理历史';
    }
    if (this.action.id === WorkbenchActionId.ArchiveRecordQuery) {
      return '查看档案变更历史';
    }
    if (this.action.id === WorkbenchActionId.ReviewRecordQuery) {
      return '查看审核处理历史';
    }
    if (this.action.id === WorkbenchActionId.RecordQuery) {
      return '统一检索系统业务记录';
    }
    return '进入业务功能';
  }
}
