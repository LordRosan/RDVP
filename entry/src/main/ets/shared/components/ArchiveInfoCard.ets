import { DeviceStatus, DeviceSummary } from '../../archive/models/DeviceModels';
import { DeviceService } from '../../archive/services/DeviceService';
import { AppColors, AppRadii } from '../theme/AppTheme';
import { StatusInfoRow } from './StatusInfoRow';

@Component
export struct ArchiveInfoCard {
  @Prop device: DeviceSummary = {
    id: '',
    deviceCode: '-',
    name: '-',
    model: '-',
    manufacturer: '-',
    location: {
      address: '-'
    },
    status: DeviceStatus.PendingVerification
  };

  build() {
    Column() {
      this.InfoRow('设备编号', this.device.deviceCode)
      this.CardDivider()
      this.InfoRow('设备名称', this.device.name)
      this.CardDivider()
      this.InfoRow('设备型号', this.device.model)
      this.CardDivider()
      this.InfoRow('生产厂商', this.device.manufacturer)
      this.CardDivider()
      this.InfoRow('设备位置', this.device.location.address)
      this.CardDivider()
      this.InfoRow('最近核验', DeviceService.formatTimestampForDisplay(this.device.lastVerificationTime))
    }
    .width('100%')
    .backgroundColor(AppColors.SurfaceRaised)
    .borderRadius(AppRadii.Large)
    .border({
      width: 1,
      color: AppColors.Divider
    })
  }

  @Builder
  InfoRow(label: string, value: string) {
    StatusInfoRow({
      label,
      value,
      tone: AppColors.TextSecondary,
      valueMaxLines: 2,
      verticalPadding: 12
    })
  }

  @Builder
  CardDivider() {
    Divider()
      .height(1)
      .backgroundColor(AppColors.Divider)
      .margin({
        left: 18,
        right: 18
      })
  }
}
