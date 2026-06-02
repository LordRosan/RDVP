import { AuthService } from '../services/AuthService';
import { ApiClient } from '../services/ApiClient';
import { SessionStore } from '../stores/SessionStore';

@Entry
@Component
struct Login {
  @State username: string = '';
  @State password: string = '';
  @State apiBaseUrl: string = ApiClient.getBaseUrl();
  @State message: string = '';
  @State messageTone: string = '#D9480F';
  @State submitting: boolean = false;

  aboutToAppear(): void {
    if (SessionStore.isAuthenticated()) {
      this.openWorkbench();
      return;
    }

    this.apiBaseUrl = ApiClient.getBaseUrl();
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
    .backgroundColor('#F2F5F7')
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
            .fontColor('#FFFFFF')
            .maxLines(1)
        }
        .width(52)
        .height(52)
        .borderRadius(16)
        .backgroundColor('#2F6FED')

        Column({ space: 4 }) {
          Text('RDVP')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .maxLines(1)

          Text('远程设备核验与运维报告系统')
            .fontSize(14)
            .fontColor('#5B6472')
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
          .fontColor('#111827')
          .maxLines(1)

        Text('验证身份后进入业务工作台')
          .fontSize(14)
          .fontColor('#6B7280')
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
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  InputField(label: string, placeholder: string, secure: boolean) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111827')
        .maxLines(1)

      TextInput({
        placeholder,
        text: secure ? this.password : this.username
      })
        .type(secure ? InputType.Password : InputType.Normal)
        .height(54)
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
          if (secure) {
            this.password = value;
          } else {
            this.username = value;
          }
          this.message = '';
          this.messageTone = '#D9480F';
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ServiceConfigPanel() {
    Column({ space: 10 }) {
      Row() {
        Text('后端服务')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
          .layoutWeight(1)
          .maxLines(1)

        Text(ApiClient.getRuntimeStatusLabel())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(ApiClient.getRuntimeStatusTone())
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      TextInput({
        placeholder: 'http://192.168.x.x:8080',
        text: this.apiBaseUrl
      })
        .height(50)
        .fontSize(15)
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
          this.apiBaseUrl = value;
          this.message = '';
          this.messageTone = '#D9480F';
        })

      Row({ space: 10 }) {
        Column() {
          this.ServiceButton('保存地址', $r('sys.symbol.checkmark_circle'), '#2F6FED', '#FFFFFF', () => {
            this.saveApiBaseUrl();
          })
        }
        .layoutWeight(1)

        Column() {
          this.ServiceButton('本地模式', $r('sys.symbol.xmark_circle'), '#FFFFFF', '#111827', () => {
            this.clearApiBaseUrl();
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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
      color: backgroundColor === '#FFFFFF' ? '#D6DAE1' : backgroundColor
    })
    .onClick(() => {
      action();
    })
  }

  @Builder
  LoginButton() {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.person_badge_checkmark'))
          .fontSize(20)
          .fontColor(['#FFFFFF'])

        Text(this.submitting ? '登录中' : '登录')
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
    const response = await AuthService.loginRemoteFirst({
      username: this.username,
      password: this.password
    });
    this.submitting = false;

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '登录失败';
      this.messageTone = '#D9480F';
      return;
    }

    if (response.data !== undefined) {
      SessionStore.setSession(response.data);
    }

    this.openWorkbench();
  }

  saveApiBaseUrl(): void {
    const value = this.apiBaseUrl.trim();
    const validationMessage = ApiClient.validateBaseUrlInput(value);
    if (validationMessage.length > 0) {
      this.message = validationMessage;
      this.messageTone = '#D9480F';
      return;
    }

    ApiClient.setBaseUrl(value);
    this.apiBaseUrl = ApiClient.getBaseUrl();
    this.message = ApiClient.isConfigured() ? '服务地址已保存' : '已切换为本地模式';
    this.messageTone = ApiClient.isConfigured() ? '#087F5B' : '#2F6FED';
  }

  clearApiBaseUrl(): void {
    ApiClient.setBaseUrl('');
    this.apiBaseUrl = '';
    this.message = '已切换为本地模式';
    this.messageTone = '#2F6FED';
  }

  openWorkbench(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Workbench' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }
}
