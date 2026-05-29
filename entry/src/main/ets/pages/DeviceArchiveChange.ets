import { InfoDialog, InfoDialogSection } from '../components/InfoDialog';
import {
  DeviceArchiveChangeBaseline,
  DeviceArchiveChangeDraft,
  DeviceArchiveChangeRequestForm,
  DeviceArchiveChangeRequestStatus
} from '../models/DeviceArchiveChangeModels';
import { DeviceArchiveChangeService } from '../services/DeviceArchiveChangeService';
import { DeviceService } from '../services/DeviceService';
import { DeviceArchiveFlowStore } from '../stores/DeviceArchiveFlowStore';

const DEVICE_CHANGE_INFO_SECTIONS: InfoDialogSection[] = [
  {
    title: '变更申请',
    items: [
      {
        label: '提交申请',
        description: '填写需要修正的设备档案字段和变更原因，形成待审核申请'
      },
      {
        label: '审核生效',
        description: '申请通过管理员审核后才会写入正式设备档案，避免误改和越权修改'
      }
    ]
  },
  {
    title: '变更内容',
    items: [
      {
        label: '设备名称',
        description: '用于识别设备业务含义，名称应清晰、稳定，避免临时描述'
      },
      {
        label: '设备型号',
        description: '记录设备规格或版本信息，便于后续维修、备件和兼容性判断'
      },
      {
        label: '生产厂商',
        description: '记录设备来源方或制造方，便于追溯质量、保修和技术支持责任'
      },
      {
        label: '设备位置',
        description: '记录设备当前部署位置，应能支持现场定位和运维派发'
      }
    ]
  }
];

@Entry
@Component
struct DeviceArchiveChange {
  @State deviceCode: string = '';
  @State deviceName: string = '';
  @State model: string = '';
  @State manufacturer: string = '';
  @State locationAddress: string = '';
  @State reason: string = '';
  @State message: string = '';
  @State normalizedDeviceCode: string = '-';
  @State changeCount: number = 0;
  @State requestStatus: DeviceArchiveChangeRequestStatus = DeviceArchiveChangeRequestStatus.Draft;
  @State hasDevice: boolean = false;
  private baseline?: DeviceArchiveChangeBaseline = undefined;
  private changeInfoDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoDialog({
      title: '设备档案变更说明',
      sections: DEVICE_CHANGE_INFO_SECTIONS
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    this.loadArchiveContext();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.ChangeForm()
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
    this.backToDetail();
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
        this.backToDetail();
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
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text('设备档案变更')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.InfoButton(() => {
          this.showChangeInfoDialog();
        })
      }
      .alignItems(VerticalAlign.Center)

      Text('提交设备档案修改申请')
        .fontSize(15)
        .fontColor('#6B7280')
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
  ChangeForm() {
    Column({ space: 16 }) {
      this.DeviceCodeField()
      this.ChangeInputField('设备名称', '填写新的设备名称', this.deviceName, (value: string) => {
        this.deviceName = value;
      })
      this.ChangeInputField('设备型号', '填写新的设备型号', this.model, (value: string) => {
        this.model = value;
      })
      this.ChangeInputField('生产厂商', '填写新的生产厂商', this.manufacturer, (value: string) => {
        this.manufacturer = value;
      })
      this.ChangeInputField('设备位置', '填写新的设备位置', this.locationAddress, (value: string) => {
        this.locationAddress = value;
      })
      this.ReasonField()
      this.MessageText()
      this.ActionButton('提交申请', $r('sys.symbol.checkmark_circle'), this.hasDevice, () => {
        this.submitChangeRequest();
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
        placeholder: '设备编号',
        text: this.deviceCode
      })
        .height(56)
        .fontSize(16)
        .backgroundColor('#F7F9FC')
        .fontColor('#6B7280')
        .borderRadius(18)
        .padding({
          left: 16,
          right: 16
        })
        .border({
          width: 1,
          color: '#D6DAE1'
        })
        .enabled(false)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ChangeInputField(title: string, placeholder: string, textValue: string, inputAction: (value: string) => void) {
    Column({ space: 10 }) {
      this.FieldTitle(title)

      TextInput({
        placeholder,
        text: textValue
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
          inputAction(value);
          this.message = '';
          this.updateChangeCount();
          this.saveDraft();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ReasonField() {
    Column({ space: 10 }) {
      this.FieldTitle('变更原因')

      TextArea({
        placeholder: '填写变更依据、现场情况或补充说明',
        text: this.reason
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
          this.reason = value;
          this.message = '';
          this.saveDraft();
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
  ActionButton(label: string, icon: Resource, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: enabled }) {
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
    .backgroundColor(enabled ? '#2F6FED' : '#AEB6C2')
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
        .fontColor(['#111827'])
    }
    .width(28)
    .height(28)
    .backgroundColor('#00000000')
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
        this.StatusRow('变更字段', `${this.changeCount}项`, '#374151')
        this.CardDivider()
        this.StatusRow('申请状态', DeviceArchiveChangeService.formatRequestStatus(this.requestStatus),
          this.getStatusTone(this.requestStatus))
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

  submitChangeRequest(): void {
    const form = this.buildForm();
    const validation = DeviceArchiveChangeService.validateChangeRequestForm(form);
    this.normalizedDeviceCode = validation.normalizedDeviceCode ?
      validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(this.deviceCode);
    this.changeCount = validation.changeCount !== undefined ?
      validation.changeCount : DeviceArchiveChangeService.countChangedFields(form);
    if (this.normalizedDeviceCode.length === 0) {
      this.normalizedDeviceCode = '-';
    }

    if (!validation.valid) {
      this.message = validation.message;
      return;
    }

    const response = DeviceArchiveChangeService.submitChangeRequest(form);
    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '变更申请提交失败';
      return;
    }

    this.requestStatus = DeviceArchiveChangeRequestStatus.PendingReview;
    DeviceArchiveFlowStore.markChangePending(response.data ? response.data.id : '');
    this.message = '变更申请已提交，等待管理员审核';
  }

  buildForm(): DeviceArchiveChangeRequestForm {
    return {
      deviceCode: this.deviceCode,
      deviceName: this.deviceName,
      model: this.model,
      manufacturer: this.manufacturer,
      locationAddress: this.locationAddress,
      reason: this.reason,
      baseline: this.baseline
    };
  }

  updateChangeCount(): void {
    this.changeCount = DeviceArchiveChangeService.countChangedFields(this.buildForm());
    this.requestStatus = DeviceArchiveChangeRequestStatus.Draft;
  }

  getStatusTone(status: DeviceArchiveChangeRequestStatus): string {
    switch (status) {
      case DeviceArchiveChangeRequestStatus.PendingReview:
        return '#E67700';
      case DeviceArchiveChangeRequestStatus.Approved:
        return '#087F5B';
      case DeviceArchiveChangeRequestStatus.Rejected:
        return '#D9480F';
      case DeviceArchiveChangeRequestStatus.Draft:
      default:
        return '#374151';
    }
  }

  showChangeInfoDialog(): void {
    this.changeInfoDialogController.open();
  }

  loadArchiveContext(): void {
    const device = DeviceArchiveFlowStore.getCurrentDevice();
    if (device === undefined) {
      this.hasDevice = false;
      this.message = '未获取设备档案，请返回后重新查询';
      return;
    }

    this.hasDevice = true;
    this.baseline = {
      deviceName: device.name,
      model: device.model,
      manufacturer: device.manufacturer,
      locationAddress: device.location.address
    };

    const draft = DeviceArchiveFlowStore.getDraft();
    if (draft !== undefined && draft.deviceCode === device.deviceCode) {
      this.applyDraft(draft);
    } else {
      this.deviceCode = device.deviceCode;
      this.deviceName = device.name;
      this.model = device.model;
      this.manufacturer = device.manufacturer;
      this.locationAddress = device.location.address;
      this.reason = '';
    }

    this.normalizedDeviceCode = DeviceService.normalizeDeviceCode(this.deviceCode);
    this.updateChangeCount();
  }

  applyDraft(draft: DeviceArchiveChangeDraft): void {
    this.deviceCode = draft.deviceCode;
    this.deviceName = draft.deviceName;
    this.model = draft.model;
    this.manufacturer = draft.manufacturer;
    this.locationAddress = draft.locationAddress;
    this.reason = draft.reason;
  }

  saveDraft(): void {
    if (!this.hasDevice) {
      return;
    }

    DeviceArchiveFlowStore.saveDraft({
      deviceCode: this.deviceCode,
      deviceName: this.deviceName,
      model: this.model,
      manufacturer: this.manufacturer,
      locationAddress: this.locationAddress,
      reason: this.reason
    });
  }

  backToDetail(): void {
    try {
      const router = this.getUIContext().getRouter();
      if (router.getState().index > 1) {
        router.back();
        return;
      }

      router.replaceUrl({ url: 'pages/DeviceArchiveDetail' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }
}
