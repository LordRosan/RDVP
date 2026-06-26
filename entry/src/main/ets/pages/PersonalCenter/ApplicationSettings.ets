import { AppColors, AppRadii, AppSpacing } from '../../styles/AppTheme';
import { common } from '@kit.AbilityKit';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { AppThemeMode } from '../../models/app/ThemeModels';
import { AppThemeService } from '../../services/app/AppThemeService';
import { UiFeedbackService } from '../../services/common/UiFeedbackService';
import { SessionStore } from '../../stores/SessionStore';
import { UiFeedbackTone } from '../../models/common/UiFeedbackModels';
import { AppNavigator } from '../../utils/AppNavigator';

@Entry
@Component
struct ApplicationSettings {
  @State selectedThemeMode: string = AppThemeService.getThemeMode();
  @State themeModeMessage: string = '';
  @State themeModeMessageTone: string = UiFeedbackTone.Success;
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;

  aboutToAppear(): void {
    if (!SessionStore.isAuthenticated()) {
      this.openLoginPage();
      return;
    }

    this.selectedThemeMode = AppThemeService.getThemeMode();
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: AppSpacing.Section }) {
          this.ModeHeader()
          this.DisplayPanel()
        }
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: AppSpacing.PageX,
          right: AppSpacing.PageX,
          top: 0,
          bottom: AppSpacing.PageBottom
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
    this.backToPersonalCenter();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToPersonalCenter();
      }
    })
  }

  @Builder
  ModeHeader() {
    Column({ space: 5 }) {
      Text('应用设置')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Application Settings')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({
      left: 0,
      right: 0,
      top: 12,
      bottom: 6
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DisplayPanel() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '显示设置',
        subtitle: ''
      })

      Column({ space: 12 }) {
        this.InfoRow('显示模式', AppThemeService.getThemeModeLabel(this.getSelectedThemeMode()), AppColors.TextSecondary)
        this.CardDivider()

        this.ThemeModeMessageText()

        Row({ space: 8 }) {
          Column() {
            this.ThemeModeButton(AppThemeMode.FollowSystem, '跟随系统', $r('sys.symbol.gearshape'))
          }
          .layoutWeight(1)

          Column() {
            this.ThemeModeButton(AppThemeMode.Light, '浅色', $r('sys.symbol.sun_max'))
          }
          .layoutWeight(1)

          Column() {
            this.ThemeModeButton(AppThemeMode.Dark, '深色', $r('sys.symbol.moon'))
          }
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .padding({
        left: 18,
        right: 18,
        top: 12,
        bottom: 18
      })
      .width('100%')
      .backgroundColor(AppColors.SurfaceRaised)
      .borderRadius(AppRadii.Large)
      .border({
        width: 1,
        color: AppColors.Divider
      })
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
    .width('100%')
  }

  @Builder
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
  }

  @Builder
  ThemeModeMessageText() {
    if (this.themeModeMessage.length > 0) {
      InlineMessageSurface({
        message: this.themeModeMessage,
        tone: this.themeModeMessageTone
      })
    }
  }

  @Builder
  ThemeModeButton(mode: AppThemeMode, label: string, icon: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 5 }) {
        SymbolGlyph(icon)
          .fontSize(16)
          .fontColor([this.isThemeModeSelected(mode) ? AppColors.OnPrimary : AppColors.TextPrimary])

        Text(label)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isThemeModeSelected(mode) ? AppColors.OnPrimary : AppColors.TextPrimary)
          .maxLines(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(42)
    .width('100%')
    .backgroundColor(this.isThemeModeSelected(mode) ? AppColors.Primary : AppColors.SurfaceRaised)
    .border({
      width: 1,
      color: this.isThemeModeSelected(mode) ? AppColors.Primary : AppColors.Border
    })
    .onClick(() => {
      this.selectThemeMode(mode);
    })
  }

  selectThemeMode(mode: AppThemeMode): void {
    this.selectedThemeMode = mode;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.themeModeMessage = UiFeedbackService.operationUnavailable('设置');
      this.themeModeMessageTone = UiFeedbackTone.Danger;
      return;
    }

    const abilityContext = context as common.UIAbilityContext;
    AppThemeService.setThemeMode(mode, abilityContext.getApplicationContext(), abilityContext.config);
    this.selectedThemeMode = mode;
    this.themeModeMessage = UiFeedbackService.operationSuccess('设置');
    this.themeModeMessageTone = UiFeedbackTone.Success;
  }

  getSelectedThemeMode(): AppThemeMode {
    if (this.selectedThemeMode === AppThemeMode.Light) {
      return AppThemeMode.Light;
    }

    if (this.selectedThemeMode === AppThemeMode.Dark) {
      return AppThemeMode.Dark;
    }

    return AppThemeMode.FollowSystem;
  }

  isThemeModeSelected(mode: AppThemeMode): boolean {
    return this.getSelectedThemeMode() === mode;
  }

  backToPersonalCenter(): void {
    AppNavigator.backOrReplace(this.getUIContext(), 'pages/PersonalCenter/PersonalCenter', {
      onFailure: () => {
        AppNavigator.showNavigationUnavailableToast(this.getUIContext());
      }
    });
  }

  openLoginPage(): void {
    AppNavigator.replace(this.getUIContext(), 'pages/Login', () => {
      AppNavigator.showNavigationUnavailableToast(this.getUIContext());
    });
  }
}
