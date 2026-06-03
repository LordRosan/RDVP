import { AppColors } from '../../styles/AppTheme';
import { InfoDialog, InfoDialogSection } from '../../components/InfoDialog';
import { StatusInfoRow } from '../../components/StatusInfoRow';
import { PermissionCode } from '../../models/PermissionModels';
import { VerificationResult } from '../../models/VerificationModels';
import { ApiClient } from '../../services/ApiClient';
import { DeviceService } from '../../services/DeviceService';
import { DeviceVerificationService } from '../../services/DeviceVerificationService';
import { OperationsFlowStore } from '../../stores/OperationsFlowStore';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';

const VERIFICATION_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '状态核验',
    items: [
      {
        label: '现场记录',
        description: '记录设备当前运行、环境、外观和核验依据，形成可追溯的现场状态记录'
      }
    ]
  },
  {
    title: '核验结果',
    items: [
      {
        label: '正常',
        description: '关键功能、状态指标和现场环境未见异常，设备可按原业务流程继续运行'
      },
      {
        label: '异常',
        description: '发现偏离预期的状态、现象或风险信号，应补充说明并视情况提交故障报告'
      },
      {
        label: '不可用',
        description: '设备无法完成基本业务能力或存在明显安全风险，应停止使用并进入维修流程'
      }
    ]
  }
];

@Entry
@Component
struct DeviceVerification {
  @State deviceCode: string = '';
  @State verificationResult: string = '';
  @State description: string = '';
  @State remark: string = '';
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State normalizedDeviceCode: string = '-';
  @State submitting: boolean = false;
  @State canReportFault: boolean = false;
  private verificationInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '状态核验说明',
      sections: VERIFICATION_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    AuthGuard.requirePermission(this.getUIContext(), PermissionCode.OpsDeviceVerify);
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.VerificationForm()
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
        Text('状态核验')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.InfoButton(() => {
          this.showVerificationInfoDialog();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text('记录设备现场状态')
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
  VerificationForm() {
    Column({ space: 16 }) {
      this.DeviceCodeField()
      this.ResultSelector()
      this.DescriptionField()
      this.RemarkField()
      this.MessageText()
      this.ActionButton(this.submitting ? '提交中' : '提交核验', $r('sys.symbol.checkmark_circle'), !this.submitting,
        () => {
          this.submitVerification();
        })
      if (this.canReportFault) {
        this.ActionButton('上报故障', $r('sys.symbol.exclamationmark_message'), true, () => {
          this.openFaultReport();
        })
      }
    }
    .padding({
      left: 18,
      right: 18,
      top: 18,
      bottom: 18
    })
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DeviceCodeField() {
    Column({ space: 10 }) {
      this.FieldTitle('设备编号')

      TextInput({
        placeholder: '输入设备编号',
        text: this.deviceCode
      })
        .height(56)
        .fontSize(16)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({
          left: 16,
          right: 16
        })
        .border({
          width: 1,
          color: AppColors.Border
        })
        .onChange((value: string) => {
          this.deviceCode = value;
          this.message = '';
          this.messageTone = AppColors.Danger;
          this.canReportFault = false;
          this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(value);
          if (this.normalizedDeviceCode.length === 0) {
            this.normalizedDeviceCode = '-';
          }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ResultSelector() {
    Column({ space: 10 }) {
      this.FieldTitle('核验结果')

      Row({ space: 10 }) {
        this.ResultOption(VerificationResult.Normal, $r('sys.symbol.checkmark_circle'))
        this.ResultOption(VerificationResult.Abnormal, $r('sys.symbol.exclamationmark_shield_fill'))
        this.ResultOption(VerificationResult.Unavailable, $r('sys.symbol.xmark_circle'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ResultOption(result: VerificationResult, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 5 }) {
        SymbolGlyph(icon)
          .fontSize(17)
          .fontColor([this.verificationResult === `${result}` ? AppColors.Surface : AppColors.TextPrimary])

        Text(DeviceVerificationService.formatVerificationResult(result))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.verificationResult === `${result}` ? AppColors.Surface : AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor(this.verificationResult === `${result}` ? this.getResultTone(result) : AppColors.FieldBackground)
    .border({
      width: 1,
      color: this.verificationResult === `${result}` ? this.getResultTone(result) : AppColors.Border
    })
    .onClick(() => {
      this.verificationResult = `${result}`;
      this.message = '';
      this.messageTone = AppColors.Danger;
      this.canReportFault = false;
    })
  }

  @Builder
  DescriptionField() {
    Column({ space: 10 }) {
      this.FieldTitle('现场描述')

      TextArea({
        placeholder: '填写现场状态、异常现象或核验依据',
        text: this.description
      })
        .height(118)
        .width('100%')
        .fontSize(15)
        .lineHeight(22)
        .maxLength(500)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({
          left: 14,
          right: 14,
          top: 12,
          bottom: 12
        })
        .border({
          width: 1,
          color: AppColors.Border
        })
        .onChange((value: string) => {
          this.description = value;
          this.message = '';
          this.messageTone = AppColors.Danger;
          this.canReportFault = false;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RemarkField() {
    Column({ space: 10 }) {
      this.FieldTitle('备注')

      TextArea({
        placeholder: '填写补充说明',
        text: this.remark
      })
        .height(86)
        .width('100%')
        .fontSize(15)
        .lineHeight(22)
        .maxLength(300)
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(18)
        .padding({
          left: 14,
          right: 14,
          top: 12,
          bottom: 12
        })
        .border({
          width: 1,
          color: AppColors.Border
        })
        .onChange((value: string) => {
          this.remark = value;
          this.message = '';
          this.messageTone = AppColors.Danger;
          this.canReportFault = false;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  FieldTitle(title: string) {
    Text(title)
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .fontColor(AppColors.TextPrimary)
      .maxLines(1)
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(13)
        .fontColor(this.messageTone)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ActionButton(label: string, icon: Resource, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([AppColors.Surface])

        Text(label)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.Surface)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .width('100%')
    .backgroundColor(AppColors.Primary)
    .enabled(enabled)
    .onClick(() => {
      action();
    })
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
  StatusPanel() {
    Column({ space: 10 }) {
      Text('提交状态')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        StatusInfoRow({ label: '标准编号', value: this.normalizedDeviceCode, tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({ label: '操作人', value: SessionStore.getCurrentOperatorName(), tone: AppColors.TextSecondary })
        this.CardDivider()
        StatusInfoRow({
          label: '核验结果',
          value: this.getVerificationResultStatusText(),
          tone: this.getSelectedResultTone()
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
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
      .margin({
        left: 18,
        right: 18
      })
  }

  async submitVerification(): Promise<void> {
    if (this.submitting) {
      return;
    }

    this.submitting = true;
    const response = await DeviceVerificationService.submitVerificationRemoteFirst({
      deviceCode: this.deviceCode,
      result: this.verificationResult as VerificationResult,
      description: this.description,
      remark: this.remark
    });
    this.submitting = false;

    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '核验提交失败';
      this.messageTone = AppColors.Danger;
      return;
    }

    const recordId = response.data ? response.data.id : '';
    if (DeviceVerificationService.isOfflineSyncQueuedResponse(response)) {
      this.message = recordId.length > 0 ? `核验记录已在本地提交，待在线同步：${recordId}` : '核验记录已在本地提交，待在线同步';
    } else {
      this.message = recordId.length > 0 ? `核验记录已提交：${recordId}` : '核验记录已提交';
    }
    this.messageTone = AppColors.Success;
    this.canReportFault = this.shouldOfferFaultReport();
  }

  getVerificationResultStatusText(): string {
    return this.verificationResult.length === 0 ? '-' :
      DeviceVerificationService.formatVerificationResult(this.verificationResult as VerificationResult);
  }

  getSelectedResultTone(): string {
    return this.verificationResult.length === 0 ? AppColors.TextSecondary : this.getResultTone(this.verificationResult as VerificationResult);
  }

  getResultTone(result: VerificationResult): string {
    switch (result) {
      case VerificationResult.Normal:
        return AppColors.Success;
      case VerificationResult.Abnormal:
        return AppColors.Danger;
      case VerificationResult.Unavailable:
        return AppColors.TextSecondary;
      default:
        return AppColors.TextSecondary;
    }
  }

  showVerificationInfoDialog(): void {
    this.verificationInfoDialogController.open();
  }

  shouldOfferFaultReport(): boolean {
    return this.verificationResult !== `${VerificationResult.Normal}` &&
      SessionStore.hasPermission(PermissionCode.OpsFaultReportCreate);
  }

  openFaultReport(): void {
    const resultText = DeviceVerificationService.formatVerificationResult(this.verificationResult as VerificationResult);
    const description = this.description.trim();
    const remark = this.remark.trim();
    OperationsFlowStore.setFaultReportPrefill({
      deviceCode: this.normalizedDeviceCode === '-' ? this.deviceCode : this.normalizedDeviceCode,
      description: description.length > 0 ? `状态核验结果为${resultText}。${description}` : `状态核验结果为${resultText}。`,
      sceneCondition: remark
    });

    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/OperationsCenter/FaultReport' });
    } catch (err) {
      this.message = '故障报告不可用';
      this.messageTone = AppColors.Danger;
    }
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
      this.message = '页面跳转失败';
      this.messageTone = AppColors.Danger;
    }
  }
}
