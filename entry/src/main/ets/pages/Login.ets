import { AppColors } from '../styles/AppTheme';
import { AuthService } from '../services/AuthService';
import { ApiClient } from '../services/ApiClient';
import { ServiceMode } from '../models/ServiceModeModels';
import { SessionStore } from '../stores/SessionStore';

@Entry
@Component
struct Login {
  @State username: string = '';
  @State password: string = '';
  @State selectedServiceMode: string = ApiClient.getServiceMode();
  @State apiBaseUrl: string = ApiClient.getBaseUrl();
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State serviceModeMessage: string = '';
  @State serviceModeMessageTone: string = AppColors.Success;
  @State serviceAddressMessage: string = '';
  @State serviceAddressMessageTone: string = AppColors.Success;
  @State submitting: boolean = false;

  aboutToAppear(): void {
    if (SessionStore.isAuthenticated()) {
      this.openWorkbench();
      return;
    }

    this.apiBaseUrl = ApiClient.getBaseUrl();
    this.selectedServiceMode = ApiClient.getServiceMode();
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        Blank()
          .height(12)

        Column({ space: 22 }) {
          this.BrandHeader()
          this.LoginPanel()
        }
        .width('100%')
        .padding({
          left: 24,
          right: 24
        })

        Blank()
          .height(12)
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Center)
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    return true;
  }

  @Builder
  BrandHeader() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Stack() {
          Text('RD')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.Surface)
            .maxLines(1)
        }
        .width(52)
        .height(52)
        .borderRadius(16)
        .backgroundColor(AppColors.Primary)

        Column({ space: 4 }) {
          Text('RDVP')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)

          Text('远程设备核验与运维报告系统')
            .fontSize(14)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  LoginPanel() {
    Column({ space: 18 }) {
      Column({ space: 6 }) {
        Text('登录')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)

        Text('验证身份后进入业务工作台')
          .fontSize(14)
          .fontColor(AppColors.TextSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      this.InputField('账号', '输入账号', false)
      this.InputField('密码', '输入密码', true)
      this.ServiceConfigPanel()
      this.MessageText()
      this.LoginButton()
    }
    .padding({
      left: 20,
      right: 20,
      top: 22,
      bottom: 22
    })
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  InputField(label: string, placeholder: string, secure: boolean) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      TextInput({
        placeholder,
        text: secure ? this.password : this.username
      })
        .type(secure ? InputType.Password : InputType.Normal)
        .height(54)
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
          if (secure) {
            this.password = value;
          } else {
            this.username = value;
          }
          this.message = '';
          this.messageTone = AppColors.Danger;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ServiceConfigPanel() {
    Column({ space: 10 }) {
      Row() {
        Text('服务模式')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary)
          .layoutWeight(1)
          .maxLines(1)

        Text(this.getSelectedRuntimeStatusLabel())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getSelectedRuntimeStatusTone())
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.ServiceModeMessageText()

      Row({ space: 10 }) {
        Column() {
          this.OnlineServiceModeButton()
        }
        .layoutWeight(1)

        Column() {
          this.OfflineServiceModeButton()
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.isOnlineSelected()) {
        TextInput({
          placeholder: 'http://192.168.x.x:8080',
          text: this.apiBaseUrl
        })
          .height(50)
          .fontSize(15)
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
            this.apiBaseUrl = value;
            this.message = '';
            this.messageTone = AppColors.Danger;
            this.serviceAddressMessage = '';
          })

        this.ServiceAddressMessageText()

        this.ServiceButton('保存地址', $r('sys.symbol.checkmark_circle'), AppColors.Primary, AppColors.Surface, () => {
          this.saveApiBaseUrl();
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ServiceModeMessageText() {
    if (this.serviceModeMessage.length > 0) {
      Text(this.serviceModeMessage)
        .fontSize(13)
        .fontColor(this.serviceModeMessageTone)
        .lineHeight(18)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ServiceAddressMessageText() {
    if (this.serviceAddressMessage.length > 0) {
      Text(this.serviceAddressMessage)
        .fontSize(13)
        .fontColor(this.serviceAddressMessageTone)
        .lineHeight(18)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  MessageText() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(13)
        .fontColor(this.messageTone)
        .lineHeight(18)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  ServiceButton(label: string, icon: Resource, backgroundColor: string, textColor: string, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 6 }) {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([textColor])

        Text(label)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(textColor)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(44)
    .width('100%')
    .backgroundColor(backgroundColor)
    .border({
      width: 1,
      color: backgroundColor === AppColors.Surface ? AppColors.Border : backgroundColor
    })
    .onClick(() => {
      action();
    })
  }

  @Builder
  OnlineServiceModeButton() {
    if (this.isOnlineSelected()) {
      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle'))
            .fontSize(18)
            .fontColor([AppColors.Surface])

          Text('在线模式')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.Surface)
            .maxLines(1)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .height(44)
      .width('100%')
      .backgroundColor(AppColors.Success)
      .border({
        width: 1,
        color: AppColors.Success
      })
      .onClick(() => {
        this.selectServiceMode(ServiceMode.Online);
      })
    } else {
      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle'))
            .fontSize(18)
            .fontColor([AppColors.TextPrimary])

          Text('在线模式')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .height(44)
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .border({
        width: 1,
        color: AppColors.Border
      })
      .onClick(() => {
        this.selectServiceMode(ServiceMode.Online);
      })
    }
  }

  @Builder
  OfflineServiceModeButton() {
    if (this.isOfflineSelected()) {
      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.xmark_circle'))
            .fontSize(18)
            .fontColor([AppColors.Surface])

          Text('离线模式')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.Surface)
            .maxLines(1)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .height(44)
      .width('100%')
      .backgroundColor(AppColors.Warning)
      .border({
        width: 1,
        color: AppColors.Warning
      })
      .onClick(() => {
        this.selectServiceMode(ServiceMode.Offline);
      })
    } else {
      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.xmark_circle'))
            .fontSize(18)
            .fontColor([AppColors.TextPrimary])

          Text('离线模式')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .height(44)
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .border({
        width: 1,
        color: AppColors.Border
      })
      .onClick(() => {
        this.selectServiceMode(ServiceMode.Offline);
      })
    }
  }

  @Builder
  LoginButton() {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.person_badge_checkmark'))
          .fontSize(20)
          .fontColor([AppColors.Surface])

        Text(this.submitting ? '登录中' : '登录')
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
    .enabled(!this.submitting)
    .onClick(() => {
      this.submitLogin();
    })
  }

  async submitLogin(): Promise<void> {
    if (this.submitting) {
      return;
    }

    this.submitting = true;
    ApiClient.setServiceMode(this.getSelectedServiceMode());
    if (this.isOnlineSelected()) {
      const validationMessage = ApiClient.validateRequiredBaseUrlInput(this.apiBaseUrl);
      if (validationMessage.length > 0) {
        this.message = validationMessage;
        this.messageTone = AppColors.Danger;
        this.submitting = false;
        return;
      }

      ApiClient.setBaseUrl(this.apiBaseUrl);
      this.apiBaseUrl = ApiClient.getBaseUrl();
    }

    const response = await AuthService.loginRemoteFirst({
      username: this.username,
      password: this.password
    });
    this.submitting = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '登录失败';
      this.messageTone = AppColors.Danger;
      return;
    }

    if (response.data !== undefined) {
      SessionStore.setSession(response.data);
    }

    this.openWorkbench();
  }

  saveApiBaseUrl(): void {
    const value = this.apiBaseUrl.trim();
    const validationMessage = ApiClient.validateRequiredBaseUrlInput(value);
    if (validationMessage.length > 0) {
      this.serviceAddressMessage = validationMessage;
      this.serviceAddressMessageTone = AppColors.Danger;
      return;
    }

    ApiClient.setBaseUrl(value);
    this.apiBaseUrl = ApiClient.getBaseUrl();
    this.message = '';
    this.serviceAddressMessage = '服务地址已保存';
    this.serviceAddressMessageTone = AppColors.Success;
    this.serviceModeMessage = '';
  }

  selectServiceMode(mode: ServiceMode): void {
    this.selectedServiceMode = mode;
    if (mode === ServiceMode.Online) {
      this.serviceModeMessage = '已选择在线模式';
      this.serviceModeMessageTone = AppColors.Success;
      return;
    }

    this.serviceModeMessage = '已选择离线模式';
    this.serviceModeMessageTone = AppColors.Warning;
  }

  getSelectedRuntimeStatusLabel(): string {
    if (this.isOnlineSelected()) {
      return this.apiBaseUrl.trim().length > 0 ? '在线模式' : '在线模式未配置';
    }

    return '离线模式';
  }

  getSelectedRuntimeStatusTone(): string {
    return this.isOnlineSelected() ? AppColors.Success : AppColors.Warning;
  }

  isOnlineSelected(): boolean {
    return this.selectedServiceMode === ServiceMode.Online;
  }

  isOfflineSelected(): boolean {
    return this.selectedServiceMode === ServiceMode.Offline;
  }

  getSelectedServiceMode(): ServiceMode {
    return this.selectedServiceMode === ServiceMode.Online ? ServiceMode.Online : ServiceMode.Offline;
  }

  openWorkbench(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Workbench' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }
}
