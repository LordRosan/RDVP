import { AppColors } from '../../styles/AppTheme';
import { CurrentUserSnapshot } from '../../models/SessionModels';
import { ServiceMode } from '../../models/ServiceModeModels';
import { ApiClient } from '../../services/ApiClient';
import { OfflineSyncService } from '../../services/OfflineSyncService';
import { ServiceModeTransitionService } from '../../services/ServiceModeTransitionService';
import { SessionStore } from '../../stores/SessionStore';
import { formatConnectionStatus } from '../../utils/SessionFormat';

@Entry
@Component
struct PersonalCenter {
  @State currentUser: CurrentUserSnapshot = SessionStore.getCurrentUser();
  @State selectedServiceMode: string = ApiClient.getServiceMode();
  @State apiBaseUrl: string = ApiClient.getBaseUrl();
  @State message: string = '';
  @State messageTone: string = AppColors.Danger;

  aboutToAppear(): void {
    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    this.currentUser = SessionStore.getCurrentUser();
    this.selectedServiceMode = ApiClient.getServiceMode();
    this.apiBaseUrl = ApiClient.getBaseUrl();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: 18 }) {
          this.ModeHeader()
          this.ProfilePanel()
          this.SessionPanel()
          this.ServicePanel()
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
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text('个人中心')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('账号、权限和会话状态')
          .fontSize(15)
          .fontColor(AppColors.TextSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
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
            .fontColor([AppColors.Surface])
        }
        .width(64)
        .height(64)
        .borderRadius(32)
        .backgroundColor(AppColors.Primary)

        Column({ space: 5 }) {
          Text(this.currentUser.displayName)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.currentUser.username ?? '-')
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

      this.InfoRow('角色权限', this.currentUser.roleName, AppColors.TextSecondary)
      this.InfoRow('连接状态', formatConnectionStatus(this.currentUser.online),
        this.currentUser.online ? AppColors.Success : AppColors.Danger)
    }
    .padding(18)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SessionPanel() {
    Column({ space: 10 }) {
      Text('会话')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column() {
        this.InfoRow('有效期至', this.formatSessionExpiresAt(), AppColors.TextSecondary)
        this.CardDivider()
        this.InfoRow('登录状态', SessionStore.isAuthenticated() ? '已登录' : '未登录',
          SessionStore.isAuthenticated() ? AppColors.Success : AppColors.Danger)
      }
      .width('100%')
      .padding({
        left: 18,
        right: 18
      })
      .backgroundColor(AppColors.Surface)
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
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ServicePanel() {
    Column({ space: 10 }) {
      Text('服务')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Column({ space: 12 }) {
        this.InfoRow('服务模式', this.getSelectedRuntimeStatusLabel(), this.getSelectedRuntimeStatusTone())
        this.CardDivider()
        this.InfoRow('同步队列', OfflineSyncService.getStatusLabel(), OfflineSyncService.getStatusTone())
        this.CardDivider()

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
            placeholder: '输入后端服务地址',
            text: this.apiBaseUrl
          })
            .height(52)
            .fontSize(15)
            .backgroundColor(AppColors.FieldBackground)
            .borderRadius(18)
            .padding({
              left: 14,
              right: 14
            })
            .border({
              width: 1,
              color: AppColors.Border
            })
            .onChange((value: string) => {
              this.apiBaseUrl = value;
              this.message = '';
              this.messageTone = AppColors.Danger;
            })

        }

        this.ServiceButton('保存设置', $r('sys.symbol.checkmark_circle'),
          AppColors.Primary,
          AppColors.Surface,
          () => {
            this.applyServiceSettings();
          })

        if (this.message.length > 0) {
          Text(this.message)
            .fontSize(13)
            .fontColor(this.messageTone)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .padding({
        left: 18,
        right: 18,
        top: 12,
        bottom: 18
      })
      .width('100%')
      .backgroundColor(AppColors.Surface)
      .borderRadius(24)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  InfoRow(label: string, value: string, tone: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppColors.TextPrimary)
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
      .backgroundColor(AppColors.Divider)
  }

  @Builder
  SecondaryButton(label: string, icon: Resource, action: () => void) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 8 }) {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([AppColors.TextPrimary])

        Text(label)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(54)
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .border({
      width: 1,
      color: AppColors.Border
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
    .backgroundColor(AppColors.Danger)
    .onClick(() => {
      action();
    })
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
    .height(46)
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
    this.ServiceButton('在线模式', $r('sys.symbol.checkmark_circle'),
      this.isOnlineSelected() ? AppColors.Success : AppColors.Surface,
      this.isOnlineSelected() ? AppColors.Surface : AppColors.TextPrimary,
      () => {
        this.selectServiceMode(ServiceMode.Online);
      })
  }

  @Builder
  OfflineServiceModeButton() {
    this.ServiceButton('离线模式', $r('sys.symbol.xmark_circle'),
      this.isOfflineSelected() ? AppColors.Warning : AppColors.Surface,
      this.isOfflineSelected() ? AppColors.Surface : AppColors.TextPrimary,
      () => {
        this.selectServiceMode(ServiceMode.Offline);
      })
  }

  selectServiceMode(mode: ServiceMode): void {
    if (this.selectedServiceMode === mode) {
      this.message = mode === ServiceMode.Online ? '当前已是在线模式' : '当前已是离线模式';
      this.messageTone = mode === ServiceMode.Online ? AppColors.Success : AppColors.Warning;
      return;
    }

    this.selectedServiceMode = mode;
    this.message = mode === ServiceMode.Online ? '已选择在线模式，保存设置后需要重新登录' : '已选择离线模式，保存设置后需要重新登录';
    this.messageTone = mode === ServiceMode.Online ? AppColors.Success : AppColors.Warning;
  }

  applyServiceSettings(): void {
    const result = ServiceModeTransitionService.applyTransition({
      targetMode: this.getSelectedServiceMode(),
      apiBaseUrl: this.apiBaseUrl,
      reason: 'personal-center-service-mode'
    });

    if (!result.success || !result.changed) {
      this.message = result.message;
      this.messageTone = result.success ?
        (this.isOnlineSelected() ? AppColors.Success : AppColors.Warning) : AppColors.Danger;
      return;
    }

    if (result.requiresRelogin) {
      this.openLoginPage();
    }
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

  getSelectedServiceMode(): ServiceMode {
    return this.selectedServiceMode === ServiceMode.Online ? ServiceMode.Online : ServiceMode.Offline;
  }

  isOnlineSelected(): boolean {
    return this.selectedServiceMode === ServiceMode.Online;
  }

  isOfflineSelected(): boolean {
    return this.selectedServiceMode === ServiceMode.Offline;
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

    return `${date.getFullYear()}-${this.pad2(date.getMonth() + 1)}-${this.pad2(date.getDate())} ${this.pad2(
      date.getHours())}:${this.pad2(date.getMinutes())}`;
  }

  pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  backToWorkbench(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (err) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/Workbench' });
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
