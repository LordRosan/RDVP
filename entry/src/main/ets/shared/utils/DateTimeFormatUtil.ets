export class DateTimeFormatUtil {
  static toApiIsoString(value: string): string {
    const date = DateTimeFormatUtil.parseLocalDisplayDateTime(value);
    if (date === undefined) {
      return value.trim();
    }

    return date.toISOString();
  }

  static parseLocalDisplayDateTime(value: string): Date | undefined {
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      return undefined;
    }

    const segments = trimmed.split(' ');
    if (segments.length !== 2) {
      return undefined;
    }

    const dateSegments = segments[0].split('-');
    const timeSegments = segments[1].split(':');
    if (dateSegments.length !== 3 || timeSegments.length < 2) {
      return undefined;
    }

    const year = Number(dateSegments[0]);
    const month = Number(dateSegments[1]);
    const day = Number(dateSegments[2]);
    const hour = Number(timeSegments[0]);
    const minute = Number(timeSegments[1]);
    if (year !== year || month !== month || day !== day || hour !== hour || minute !== minute) {
      return undefined;
    }

    if (year < 2000 || year > 2100 || month < 1 || month > 12 || day < 1 || day > 31 ||
      hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return undefined;
    }

    return new Date(year, month - 1, day, hour, minute);
  }
}
