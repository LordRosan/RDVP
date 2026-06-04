import { AppColors } from '../../styles/AppTheme';
import { InfoDialog, InfoDialogSection } from '../../components/InfoDialog';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { OperationRecordSummary } from '../../models/OperationRecordModels';
import { PermissionCode } from '../../models/PermissionModels';
import { ApiClient } from '../../services/ApiClient';
import { OperationRecordService } from '../../services/OperationRecordService';
import { AuthGuard } from '../../utils/AuthGuard';

const OPERATION_RECORD_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '操作记录',
    items: [
      {
        label: '记录范围',
        description: '集中展示登录、核验、档案变更、故障、维修和复检等关键业务动作'
      },
      {
        label: '审计价值',
        description: '保留操作对象、时间、结果和摘要，便于追踪业务流程和定位异常操作'
      }
    ]
  }
];

@Entry
@Component
struct OperationRecord {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State records: OperationRecordSummary[] = [];
  @State message: string = '';
  @State refreshStatus: string = '未刷新';
  @State refreshing: boolean = false;
  private operationRecordInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '操作记录说明',
      sections: OPERATION_RECORD_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.MgmtAuditLogRead)) {
      return;
    }

    this.refreshRecords();
  }

  onPageShow(): void {
    if (AuthGuard.requirePermission(this.getUIContext(), PermissionCode.MgmtAuditLogRead)) {
      this.refreshRecords();
    }
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.RecordListPanel()
          this.StatusPanel()
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .padding({
          left: 24,
          right: 24,
          top: 0,
          bottom: 28
        })
        .width('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    this.backToWorkbench();
    return true;
  }

  @Builder
  PageTitleBar() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(22)
          .fontColor([AppColors.TextPrimary])
      }
      .width(44)
      .height(44)
      .backgroundColor(AppColors.Surface)
      .border({
        width: 1,
        color: AppColors.Divider
      })
      .onClick(() => {
        this.backToWorkbench();
      })
    }
    .width('100%')
    .height(60)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: 24,
      right: 24
    })
    .backgroundColor(AppColors.PageBackground)
  }

  @Builder
  ModeHeader() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text('操作记录')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.InfoButton(() => {
          this.operationRecordInfoDialogController.open();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text('查看关键业务流转记录')
        .fontSize(15)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      top: 0,
      bottom: 2
    })
  }

  @Builder
  RecordListPanel() {
    Column({ space: 10 }) {
      this.MessageText()

      Row() {
        Text('最近记录')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .layoutWeight(1)
          .maxLines(1)

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(22)
            .fontColor([AppColors.OnPrimary])
        }
        .width(44)
        .height(44)
        .backgroundColor(AppColors.Primary)
        .enabled(!this.refreshing)
        .onClick(() => {
          this.refreshRecords();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.records.length === 0) {
        this.EmptyState()
      } else {
        Column({ space: 12 }) {
          ForEach(this.records, (item: OperationRecordSummary) => {
            this.RecordItem(item)
          }, (item: OperationRecordSummary) => item.id)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  EmptyState() {
    Column({ space: 10 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.text_clipboard'))
          .fontSize(36)
          .fontColor([AppColors.Primary])
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColors.PrimarySurface)

      Text('暂无操作记录')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
    }
    .width('100%')
    .padding({
      left: 18,
      right: 18,
      top: 28,
      bottom: 28
    })
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  RecordItem(item: OperationRecordSummary) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.text_clipboard'))
            .fontSize(23)
            .fontColor([AppColors.OnPrimary])
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(OperationRecordService.getRecordStatusTone(item.status))

        Column({ space: 4 }) {
          Text(item.title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.targetNo)
            .fontSize(12)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(OperationRecordService.formatRecordStatus(item.status))
          .fontSize(13)
          .fontColor(OperationRecordService.getRecordStatusTone(item.status))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(OperationRecordService.formatRecordType(item.type))
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
          .layoutWeight(1)
          .maxLines(1)

        Text(item.occurredAt)
          .fontSize(13)
          .fontColor(AppColors.TextSecondary)
          .maxLines(1)
      }
      .width('100%')

      Text(item.description)
        .fontSize(13)
        .fontColor(AppColors.TextSecondary)
        .lineHeight(19)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding(16)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
  }

  @Builder
  StatusPanel() {
    Column({ space: 10 }) {
      Text('查询状态')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({ label: '记录数量', value: `${this.records.length}条`, tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({
          label: '刷新状态',
          value: this.message.length > 0 ? '刷新失败' : this.refreshStatus,
          tone: this.message.length > 0 ? AppColors.Danger : AppColors.Success
        })
        this.CardDivider()
        StatusInfoRow({
          label: '服务模式',
          value: ApiClient.getRuntimeStatusLabel(),
          tone: ApiClient.getRuntimeStatusTone()
        })
      }
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .borderRadius(24)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  InfoButton(action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize(18)
        .fontColor([AppColors.TextPrimary])
    }
    .width(28)
    .height(28)
    .backgroundColor(AppColors.Transparent)
    .onClick(() => {
      action();
    })
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(13)
        .fontColor(AppColors.Danger)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
      .margin({
        left: 18,
        right: 18
      })
  }

  async refreshRecords(): Promise<void> {
    if (this.refreshing) {
      return;
    }

    this.refreshing = true;
    const response = await OperationRecordService.queryRecentRecordsRemoteFirst();
    this.refreshing = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '操作记录刷新失败';
      this.refreshStatus = '刷新失败';
      return;
    }

    const data = response.data;
    this.records = data ? data.items : [];
    this.message = '';
    this.refreshStatus = '已刷新';
  }

  backToWorkbench(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/Workbench' });
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '页面跳转失败' });
      } catch (toastErr) {
      }
    }
  }
}
