import { AppThemeService } from '../services/AppThemeService';

export class AppColors {
  static get Primary(): string {
    return AppThemeService.isDarkTheme() ? '#5B8CFF' : '#2F6FED';
  }

  static get PrimarySurface(): string {
    return AppThemeService.isDarkTheme() ? '#1E2B45' : '#EEF4FF';
  }

  static get Success(): string {
    return AppThemeService.isDarkTheme() ? '#34D399' : '#087F5B';
  }

  static get Warning(): string {
    return AppThemeService.isDarkTheme() ? '#F59E0B' : '#E67700';
  }

  static get Danger(): string {
    return AppThemeService.isDarkTheme() ? '#F97316' : '#D9480F';
  }

  static get TextPrimary(): string {
    return AppThemeService.isDarkTheme() ? '#F8FAFC' : '#111827';
  }

  static get TextSecondary(): string {
    return AppThemeService.isDarkTheme() ? '#CBD5E1' : '#5B6472';
  }

  static get TextTertiary(): string {
    return AppThemeService.isDarkTheme() ? '#94A3B8' : '#9CA3AF';
  }

  static get Surface(): string {
    return AppThemeService.isDarkTheme() ? '#111827' : '#FFFFFF';
  }

  static get PageBackground(): string {
    return AppThemeService.isDarkTheme() ? '#0B1020' : '#F2F5F7';
  }

  static get FieldBackground(): string {
    return AppThemeService.isDarkTheme() ? '#1F2937' : '#F7F9FC';
  }

  static get Border(): string {
    return AppThemeService.isDarkTheme() ? '#334155' : '#D6DAE1';
  }

  static get Divider(): string {
    return AppThemeService.isDarkTheme() ? '#243041' : '#E5E7EB';
  }

  static get Disabled(): string {
    return AppThemeService.isDarkTheme() ? '#64748B' : '#AEB6C2';
  }

  static get Transparent(): string {
    return '#00000000';
  }

  static get Scrim(): string {
    return AppThemeService.isDarkTheme() ? '#99000000' : '#66000000';
  }

  static get OnPrimary(): string {
    return '#FFFFFF';
  }
}
