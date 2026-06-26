import { AppThemeService } from '../services/app/AppThemeService';

export class AppColors {
  static get Primary(): string {
    return AppThemeService.isDarkTheme() ? '#6EA3FF' : '#0A59F7';
  }

  static get PrimarySurface(): string {
    return AppThemeService.isDarkTheme() ? '#162742' : '#EAF2FF';
  }

  static get PrimarySoft(): string {
    return AppThemeService.isDarkTheme() ? '#233B61' : '#D7E6FF';
  }

  static get Success(): string {
    return AppThemeService.isDarkTheme() ? '#4DD8A6' : '#00875A';
  }

  static get SuccessSurface(): string {
    return AppThemeService.isDarkTheme() ? '#14382F' : '#E7F7F0';
  }

  static get Warning(): string {
    return AppThemeService.isDarkTheme() ? '#FFB454' : '#B86E00';
  }

  static get WarningSurface(): string {
    return AppThemeService.isDarkTheme() ? '#402D12' : '#FFF3DF';
  }

  static get Danger(): string {
    return AppThemeService.isDarkTheme() ? '#FF8A65' : '#C93C20';
  }

  static get DangerSurface(): string {
    return AppThemeService.isDarkTheme() ? '#421F18' : '#FDEDEA';
  }

  static get TextPrimary(): string {
    return AppThemeService.isDarkTheme() ? '#F7F9FC' : '#101828';
  }

  static get TextSecondary(): string {
    return AppThemeService.isDarkTheme() ? '#C8D1DE' : '#596273';
  }

  static get TextTertiary(): string {
    return AppThemeService.isDarkTheme() ? '#8D99AA' : '#8A94A6';
  }

  static get Surface(): string {
    return AppThemeService.isDarkTheme() ? '#151B28' : '#FFFFFF';
  }

  static get SurfaceRaised(): string {
    return AppThemeService.isDarkTheme() ? '#1B2333' : '#FFFFFF';
  }

  static get SurfaceMuted(): string {
    return AppThemeService.isDarkTheme() ? '#101827' : '#F8FAFE';
  }

  static get HeroSurface(): string {
    return AppThemeService.isDarkTheme() ? '#172035' : '#FFFFFF';
  }

  static get PageBackground(): string {
    return AppThemeService.isDarkTheme() ? '#0A0F1C' : '#F3F6FB';
  }

  static get FieldBackground(): string {
    return AppThemeService.isDarkTheme() ? '#202A3A' : '#F5F7FB';
  }

  static get Border(): string {
    return AppThemeService.isDarkTheme() ? '#334258' : '#DDE3EC';
  }

  static get Divider(): string {
    return AppThemeService.isDarkTheme() ? '#273348' : '#E8EDF5';
  }

  static get Disabled(): string {
    return AppThemeService.isDarkTheme() ? '#657184' : '#AEB8C6';
  }

  static get Transparent(): string {
    return '#00000000';
  }

  static get Scrim(): string {
    return AppThemeService.isDarkTheme() ? '#A6000000' : '#66000000';
  }

  static get OnPrimary(): string {
    return '#FFFFFF';
  }

  static get Shadow(): string {
    return AppThemeService.isDarkTheme() ? '#33000000' : '#120A2A4A';
  }

  static get HeroGlow(): string {
    return AppThemeService.isDarkTheme() ? '#335B8CFF' : '#1A0A59F7';
  }

  static surfaceForTone(tone: string): string {
    if (tone === AppColors.Success) {
      return AppColors.SuccessSurface;
    }

    if (tone === AppColors.Warning) {
      return AppColors.WarningSurface;
    }

    if (tone === AppColors.Danger) {
      return AppColors.DangerSurface;
    }

    return AppColors.PrimarySurface;
  }
}

export class AppRadii {
  static readonly Small: number = 12;
  static readonly Medium: number = 18;
  static readonly Large: number = 24;
  static readonly Hero: number = 30;
  static readonly Pill: number = 999;
}

export class AppSpacing {
  static readonly PageX: number = 20;
  static readonly PageBottom: number = 30;
  static readonly Section: number = 20;
  static readonly Card: number = 16;
  static readonly TopBar: number = 12;
}
