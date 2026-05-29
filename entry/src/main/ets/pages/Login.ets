import { AuthService } from '../services/AuthService';
import { SessionStore } from '../stores/SessionStore';

@Entry
@Component
struct Login {
  @State username: string = '';
  @State password: string = '';
  @State message: string = '';

  build() {
    Scroll() {
      Column({ space: 24 }) {
        this.Header()
        this.LoginForm()
      }
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: 22,
        right: 22,
        top: 34,
        bottom: 34
      })
      .width('100%')
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#F6F8FB')
  }

  @Builder
  Header() {
    Column({ space: 8 }) {
      Text('RDVP')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .maxLines(1)

      Text('账号登录')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#374151')
        .maxLines(1)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  LoginForm() {
    Column({ space: 16 }) {
      TextInput({
        placeholder: '账号',
        text: this.username
      })
        .height(48)
        .fontSize(15)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({
          width: 1,
          color: '#D1D5DB'
        })
        .onChange((value: string) => {
          this.username = value;
          this.message = '';
        })

      TextInput({
        placeholder: '密码',
        text: this.password
      })
        .type(InputType.Password)
        .height(48)
        .fontSize(15)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({
          width: 1,
          color: '#D1D5DB'
        })
        .onChange((value: string) => {
          this.password = value;
          this.message = '';
        })

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(13)
          .fontColor('#D9480F')
          .maxLines(2)
      }

      Button('登录')
        .height(48)
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor('#2F6FED')
        .borderRadius(8)
        .onClick(() => {
          this.submitLogin();
        })

      Button('返回工作台')
        .height(44)
        .width('100%')
        .fontSize(15)
        .fontColor('#374151')
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({
          width: 1,
          color: '#D1D5DB'
        })
        .onClick(() => {
          this.backToWorkbench();
        })
    }
    .padding(18)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .border({
      width: 1,
      color: '#E5E7EB'
    })
  }

  submitLogin(): void {
    const response = AuthService.login({
      username: this.username,
      password: this.password
    });

    if (!response.success) {
      const error = response.error;
      this.message = error ? error.message : '登录失败';
      return;
    }

    if (response.data !== undefined) {
      SessionStore.setSession(response.data);
    }

    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }

  backToWorkbench(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
      } catch (innerErr) {
        this.message = '页面跳转失败';
      }
    }
  }
}
