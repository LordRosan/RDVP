export class PermissionTextFormatter {
  static formatTwoPerLine(items: string[]): string {
    const normalizedItems = items.filter((item: string) => item.trim().length > 0);
    if (normalizedItems.length === 0) {
      return '-';
    }

    const lines: string[] = [];
    for (let index = 0; index < normalizedItems.length; index += 2) {
      const next = index + 1;
      if (next < normalizedItems.length) {
        lines.push(`${normalizedItems[index]}、${normalizedItems[next]}`);
      } else {
        lines.push(normalizedItems[index]);
      }
    }

    return lines.join('\n');
  }
}
