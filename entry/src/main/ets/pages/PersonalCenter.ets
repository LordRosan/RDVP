import { CurrentUserSnapshot } from '../models/SessionModels';
import { SessionStore } from '../stores/SessionStore';
import { formatConnectionStatus } from '../utils/SessionFormat';

@Entry
@Component
struct PersonalCenter {
  @State currentUser: CurrentUserSnapshot = SessionStore.getCurrentUser();
  @State message: string = '';

  aboutToAppear(): void {
    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    this.currentUser = SessionStore.getCurrentUser();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.ProfilePanel()
          this.SessionPanel()
          this.ActionPanel()
        }
        .alignItems(HorizontalAlign.Start)
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
        Text('个人中心')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('账号、权限和会话状态')
          .fontSize(15)
          .fontColor('#6B7280')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Stack() {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(38)
          .fontColor(['#111827'])
      }
      .width(58)
      .height(58)
      .borderRadius(29)
      .backgroundColor('#FFFFFF')
      .border({
        width: 1,
        color: '#E5E7EB'
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      bottom: 2
    })
  }

  @Builder
  ProfilePanel() {
    Column({ space: 16 }) {
      Row({ space: 14 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.person_fill'))
            .fontSize(38)
            .fontColor(['#FFFFFF'])
        }
        .width(64)
        .height(64)
        .borderRadius(32)
        .backgroundColor('#2F6FED')

        Column({ space: 5 }) {
          Text(this.currentUser.displayName)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.currentUser.username ?? '-')
            .fontSize(14)
            .fontColor('#6B7280')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.InfoRow('角色权限', this.currentUser.roleName, '#374151')
      this.InfoRow('连接状态', formatConnectionStatus(this.currentUser.online), this.currentUser.online ? '#087F5B' : '#D9480F')
    }
    .padding(18)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SessionPanel() {
    Column({ space: 10 }) {
      Text('会话')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .maxLines(1)

      Column() {
        this.InfoRow('有效期至', this.formatSessionExpiresAt(), '#374151')
        this.CardDivider()
        this.InfoRow('登录状态', SessionStore.isAuthenticated() ? '已登录' : '未登录', SessionStore.isAuthenticated() ? '#087F5B' : '#D9480F')
      }
      .width('100%')
      .padding({
        left: 18,
        right: 18
      })
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ActionPanel() {
    Column({ space: 12 }) {
      this.SecondaryButton('返回主界面', $r('sys.symbol.chevron_backward'), () => {
        this.backToWorkbench();
      })

      this.DangerButton('退出登录', $r('sys.symbol.person_badge_nosign'), () => {
        this.logout();
      })

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(13)
          .fontColor('#D9480F')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  InfoRow(label: string, value: string, tone: string) {
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
      left: 0,
      right: 0
    })
    .width('100%')
  }

  @Builder
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor('#E5E7EB')
  }

  @Builder
  SecondaryButton(label: string, icon: Resource, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor(['#111827'])

        Text(label)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .border({
      width: 1,
      color: '#D6DAE1'
    })
    .onClick(() => {
      action();
    })
  }

  @Builder
  DangerButton(label: string, icon: Resource, action: () => void) {
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
    .backgroundColor('#D9480F')
    .onClick(() => {
      action();
    })
  }

  formatSessionExpiresAt(): string {
    const expiresAt = this.currentUser.expiresAt;
    if (expiresAt === undefined || expiresAt.length === 0) {
      return '-';
    }

    const date = new Date(expiresAt);
    if (Number.isNaN(date.getTime())) {
      return expiresAt;
    }

    return `${date.getFullYear()}-${this.pad2(date.getMonth() + 1)}-${this.pad2(date.getDate())} ${this.pad2(date.getHours())}:${this.pad2(date.getMinutes())}`;
  }

  pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
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

  logout(): void {
    SessionStore.clearSession();
    this.openLoginPage();
  }

  openLoginPage(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Login' });
    } catch (err) {
      this.message = '页面跳转失败';
    }
  }
}
