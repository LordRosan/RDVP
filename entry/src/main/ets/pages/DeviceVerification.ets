import { InfoDialog, InfoDialogSection } from '../components/InfoDialog';
import { VerificationResult } from '../models/VerificationModels';
import { DeviceService } from '../services/DeviceService';
import { DeviceVerificationService } from '../services/DeviceVerificationService';

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
  @State verificationResult: VerificationResult = VerificationResult.Normal;
  @State description: string = '';
  @State remark: string = '';
  @State message: string = '';
  @State normalizedDeviceCode: string = '-';
  private verificationInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '状态核验说明',
      sections: VERIFICATION_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

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
    .backgroundColor('#F2F5F7')
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
          .fontColor(['#111827'])
      }
      .width(44)
      .height(44)
      .backgroundColor('#FFFFFF')
      .border({
        width: 1,
        color: '#E5E7EB'
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
    .backgroundColor('#F2F5F7')
  }

  @Builder
  ModeHeader() {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text('状态核验')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('记录设备现场状态')
          .fontSize(15)
          .fontColor('#6B7280')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.checkmark_shield'))
          .fontSize(32)
          .fontColor(['#111827'])
      }
      .width(58)
      .height(58)
      .backgroundColor('#FFFFFF')
      .border({
        width: 1,
        color: '#E5E7EB'
      })
      .onClick(() => {
        this.showVerificationInfoDialog();
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
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
      this.ActionButton('提交核验', $r('sys.symbol.checkmark_circle'), () => {
        this.submitVerification();
      })
    }
    .padding({
      left: 18,
      right: 18,
      top: 18,
      bottom: 18
    })
    .width('100%')
    .backgroundColor('#FFFFFF')
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
        .backgroundColor('#F7F9FC')
        .borderRadius(18)
        .padding({
          left: 16,
          right: 16
        })
        .border({
          width: 1,
          color: '#D6DAE1'
        })
        .onChange((value: string) => {
          this.deviceCode = value;
          this.message = '';
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
          .fontColor([this.verificationResult === result ? '#FFFFFF' : '#111827'])

        Text(DeviceVerificationService.formatVerificationResult(result))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.verificationResult === result ? '#FFFFFF' : '#111827')
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor(this.verificationResult === result ? this.getResultTone(result) : '#F7F9FC')
    .border({
      width: 1,
      color: this.verificationResult === result ? this.getResultTone(result) : '#D6DAE1'
    })
    .onClick(() => {
      this.verificationResult = result;
      this.message = '';
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
        .backgroundColor('#F7F9FC')
        .borderRadius(18)
        .padding({
          left: 14,
          right: 14,
          top: 12,
          bottom: 12
        })
        .border({
          width: 1,
          color: '#D6DAE1'
        })
        .onChange((value: string) => {
          this.description = value;
          this.message = '';
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
        .backgroundColor('#F7F9FC')
        .borderRadius(18)
        .padding({
          left: 14,
          right: 14,
          top: 12,
          bottom: 12
        })
        .border({
          width: 1,
          color: '#D6DAE1'
        })
        .onChange((value: string) => {
          this.remark = value;
          this.message = '';
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
      .fontColor('#111827')
      .maxLines(1)
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(13)
        .fontColor('#D9480F')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ActionButton(label: string, icon: Resource, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor(['#FFFFFF'])

        Text(label)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .width('100%')
    .backgroundColor('#2F6FED')
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
        .fontColor('#111827')
        .maxLines(1)

      Column() {
        this.StatusRow('标准编号', this.normalizedDeviceCode, '#374151')
        this.CardDivider()
        this.StatusRow('核验结果', DeviceVerificationService.formatVerificationResult(this.verificationResult),
          this.getResultTone(this.verificationResult))
        this.CardDivider()
        this.StatusRow('服务状态', '未连接', '#D9480F')
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor('#E5E7EB')
      .margin({
        left: 18,
        right: 18
      })
  }

  @Builder
  StatusRow(label: string, value: string, tone: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor('#111827')
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(value)
        .fontSize(15)
        .fontColor(tone)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
        .width('58%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(54)
    .padding({
      left: 18,
      right: 18
    })
    .width('100%')
  }

  submitVerification(): void {
    const response = DeviceVerificationService.submitVerification({
      deviceCode: this.deviceCode,
      result: this.verificationResult,
      description: this.description,
      remark: this.remark
    });

    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '核验提交失败';
    }
  }

  getResultTone(result: VerificationResult): string {
    switch (result) {
      case VerificationResult.Normal:
        return '#087F5B';
      case VerificationResult.Abnormal:
        return '#D9480F';
      case VerificationResult.Unavailable:
        return '#495057';
      default:
        return '#374151';
    }
  }

  showVerificationInfoDialog(): void {
    this.verificationInfoDialogController.open();
  }

  backToWorkbench(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/Index' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }
}
