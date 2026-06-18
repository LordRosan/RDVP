import { AppColors, AppRadii, AppSpacing } from '../styles/AppTheme';
import { AuthService } from '../services/identity/AuthService';
import { ApiClient } from '../services/common/ApiClient';
import { SessionStore } from '../stores/SessionStore';

@Entry
@Component
struct Login {
  @State username: string = '';
  @State password: string = '';
  @State apiBaseUrl: string = ApiClient.getBaseUrl();
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;
  @State serviceAddressMessage: string = '';
  @State serviceAddressMessageTone: string = AppColors.Success;
  @State submitting: boolean = false;
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;

  aboutToAppear(): void {
    if (SessionStore.isAuthenticated()) {
      this.openWorkbench();
      return;
    }

    this.apiBaseUrl = ApiClient.getBaseUrl();
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        this.BrandHeader()
        this.LoginPanel()

        Text('使用当前账号权限访问档案、运维和管理模块')
          .fontSize(12)
          .fontColor(AppColors.TextTertiary)
          .maxLines(2)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ left: 12, right: 12 })
      }
      .width('100%')
      .padding({
        left: AppSpacing.PageX,
        right: AppSpacing.PageX,
        top: 30,
        bottom: AppSpacing.PageBottom
      })
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
    Column({ space: 18 }) {
      Row({ space: 14 }) {
        Stack() {
          Text('RD')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.OnPrimary)
            .maxLines(1)
        }
        .width(56)
        .height(56)
        .borderRadius(20)
        .backgroundColor(AppColors.Primary)

        Column({ space: 4 }) {
          Text('RDVP')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)

          Text('Remote device verification platform')
            .fontSize(13)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 8 }) {
        Text('设备档案与运维协同')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('从登录开始进入统一工作台，完成查询、核验、维修、审核和记录追溯。')
          .fontSize(14)
          .fontColor(AppColors.TextSecondary)
          .lineHeight(20)
          .maxLines(3)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: 22,
      right: 22,
      top: 24,
      bottom: 22
    })
    .backgroundColor(AppColors.HeroSurface)
    .borderRadius(AppRadii.Hero)
    .border({
      width: 1,
      color: AppColors.Divider
    })
    .shadow({
      radius: 20,
      color: AppColors.Shadow,
      offsetX: 0,
      offsetY: 8
    })
  }

  @Builder
  LoginPanel() {
    Column({ space: 18 }) {
      Row() {
        Column({ space: 4 }) {
          Text('登录')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)

          Text('连接服务并验证账号')
            .fontSize(13)
            .fontColor(AppColors.TextSecondary)
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.person_badge_checkmark'))
          .fontSize(28)
          .fontColor([AppColors.Primary])
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

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
    .borderRadius(AppRadii.Large)
    .border({
      width: 1,
      color: AppColors.Divider
    })
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
        .borderRadius(AppRadii.Medium)
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
      Row({ space: 8 }) {
        Text('服务地址')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .layoutWeight(1)

        Text(ApiClient.isConfigured() ? '已配置' : '未配置')
          .fontSize(12)
          .fontColor(ApiClient.isConfigured() ? AppColors.Success : AppColors.Warning)
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
        .backgroundColor(AppColors.FieldBackground)
        .borderRadius(AppRadii.Medium)
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

      this.ServiceButton('保存地址', $r('sys.symbol.checkmark_circle'), AppColors.Primary, AppColors.OnPrimary, () => {
        this.saveApiBaseUrl();
      })
    }
    .width('100%')
    .padding({
      left: 14,
      right: 14,
      top: 14,
      bottom: 14
    })
    .backgroundColor(AppColors.SurfaceMuted)
    .borderRadius(AppRadii.Medium)
    .alignItems(HorizontalAlign.Start)
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
  LoginButton() {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.person_badge_checkmark'))
          .fontSize(20)
          .fontColor([AppColors.OnPrimary])

        Text(this.submitting ? '登录中' : '登录')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.OnPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .width('100%')
    .backgroundColor(this.submitting ? AppColors.Disabled : AppColors.Primary)
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
    const validationMessage = ApiClient.validateRequiredBaseUrlInput(this.apiBaseUrl);
    if (validationMessage.length > 0) {
      this.message = validationMessage;
      this.messageTone = AppColors.Danger;
      this.submitting = false;
      return;
    }

    ApiClient.setBaseUrl(this.apiBaseUrl);
    this.apiBaseUrl = ApiClient.getBaseUrl();

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
  }

  openWorkbench(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Workbench' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }
}
