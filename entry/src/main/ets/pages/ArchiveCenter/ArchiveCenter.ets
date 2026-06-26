import { AppColors, AppSpacing } from '../../styles/AppTheme';
import { ActionTile } from '../../components/ActionTile';
import { AppSectionTitle } from '../../components/AppSectionTitle';
import { CenterTitleBar } from '../../components/CenterTitleBar';
import { InlineMessageSurface } from '../../components/InlineMessageSurface';
import { PermissionCode } from '../../models/identity/PermissionModels';
import { MainPageAction, MainPageActionId } from '../../models/app/MainPageModels';
import { MainPageService } from '../../services/app/MainPageService';
import { UiFeedbackService } from '../../services/common/UiFeedbackService';
import { SessionStore } from '../../stores/SessionStore';
import { AuthGuard } from '../../utils/AuthGuard';
import { MainPageNavigator } from '../../utils/MainPageNavigator';
import { UiFeedbackTone } from '../../models/common/UiFeedbackModels';

@Entry
@Component
struct ArchiveCenter {
  @StorageLink('rdvp_theme_revision') themeRevision: number = 0;
  @State actions: MainPageAction[] = MainPageService.getArchiveCenterActions();
  @State message: string = '';
  @State messageTargetId: string = '';

  aboutToAppear(): void {
    if (!AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveQuery)) {
      return;
    }

    this.refreshCenterState();
  }

  onPageShow(): void {
    if (AuthGuard.requirePermission(this.getUIContext(), PermissionCode.ArchiveCenterDeviceArchiveQuery)) {
      this.refreshCenterState();
    }
  }

  build() {
    Scroll() {
      Column() {
        this.PageTitleBar()

        Column({ space: AppSpacing.Section }) {
          this.Header()
          this.PermissionSection()
          this.ActionSection()
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
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
      .justifyContent(FlexAlign.Start)
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColors.PageBackground)
  }

  onBackPress(): boolean {
    this.backToMainPage();
    return true;
  }

  @Builder
  PageTitleBar() {
    CenterTitleBar({
      action: () => {
        this.backToMainPage();
      }
    })
  }

  @Builder
  Header() {
    Column({ space: 5 }) {
      Text('档案中心')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)

      Text('Archive Center')
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
  PermissionSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '功能权限',
        subtitle: ''
      })

      Column({ space: 16 }) {
        Grid() {
          GridItem() {
            this.PermissionCell('查询档案', this.canQueryArchive())
          }

          GridItem() {
            this.PermissionCell('修改档案', this.canUpdateArchive())
          }

          GridItem() {
            this.PermissionCell('删除档案', this.canDeleteArchive())
          }

          GridItem() {
            this.PermissionCell('添加档案', this.canCreateArchive())
          }

          GridItem() {
            this.PermissionCell('导出档案', this.canExportArchive())
          }
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(14)
        .rowsGap(14)
        .width('100%')
      }
      .width('100%')
      .padding(18)
      .backgroundColor(AppColors.SurfaceRaised)
      .borderRadius(24)
      .border({
        width: 1,
        color: AppColors.Divider
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  PermissionCell(label: string, available: boolean) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Text('')
        .width(8)
        .height(8)
        .backgroundColor(available ? AppColors.Success : AppColors.Danger)
        .borderRadius(4)
    }
    .width('100%')
    .height(40)
    .padding({
      left: 12,
      right: 12
    })
    .backgroundColor(AppColors.SurfaceMuted)
    .borderRadius(16)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  ActionSection() {
    Column({ space: 12 }) {
      AppSectionTitle({
        title: '业务功能',
        subtitle: ''
      })

      Column({ space: 10 }) {
        ForEach(this.actions, (item: MainPageAction) => {
          Column({ space: 8 }) {
            if (this.messageTargetId === `${item.id}` && this.message.length > 0) {
              InlineMessageSurface({
                message: this.message,
                tone: UiFeedbackTone.Danger
              })
            }

            ActionTile({ action: item })
              .onClick(() => {
                this.openFeature(item);
              })
          }
          .width('100%')
        }, (item: MainPageAction) => item.id)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  refreshCenterState(): void {
    this.actions = MainPageService.getArchiveCenterActions();
  }

  canQueryArchive(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveQuery);
  }

  canUpdateArchive(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveUpdateRequestSubmit);
  }

  canDeleteArchive(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveDeleteRequestSubmit);
  }

  canCreateArchive(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveCreateRequestSubmit);
  }

  canExportArchive(): boolean {
    return SessionStore.hasPermission(PermissionCode.ArchiveCenterDeviceArchiveExport);
  }

  openFeature(action: MainPageAction): void {
    this.message = '';
    this.messageTargetId = '';
    if (action.id === MainPageActionId.DeviceArchiveQuery) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/DeviceArchiveQuery' });
      } catch (err) {
        this.message = UiFeedbackService.operationUnavailable('查询设备档案');
        this.messageTargetId = `${action.id}`;
      }
      return;
    }

    if (action.id === MainPageActionId.DeviceArchiveCreateRequest) {
      try {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchiveCenter/DeviceArchiveCreate' });
      } catch (err) {
        this.message = UiFeedbackService.operationUnavailable('添加设备档案');
        this.messageTargetId = `${action.id}`;
      }
      return;
    }

    this.message = UiFeedbackService.operationUnavailable('操作');
    this.messageTargetId = `${action.id}`;
  }

  backToMainPage(): void {
    if (!MainPageNavigator.replaceToMainPage(this.getUIContext())) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: UiFeedbackService.operationUnavailable('页面跳转') });
      } catch (toastErr) {
      }
    }
  }
}


