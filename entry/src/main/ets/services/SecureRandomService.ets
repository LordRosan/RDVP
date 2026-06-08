import cryptoFramework from '@ohos.security.cryptoFramework';
import util from '@ohos.util';

const UINT32_RANGE = 4294967296;

export class SecureRandomService {
  static createSixDigitCode(): string {
    return `${SecureRandomService.nextInt(100000, 999999)}`;
  }

  static createNumericSuffix(length: number = 6): string {
    const normalizedLength = length < 1 ? 1 : Math.floor(length);
    const maxValue = Math.pow(10, normalizedLength) - 1;
    return SecureRandomService.padLeft(`${SecureRandomService.nextInt(0, maxValue)}`, normalizedLength);
  }

  static createUuidSuffix(): string {
    return util.generateRandomUUID(false).replace(/-/g, '');
  }

  static nextInt(minInclusive: number, maxInclusive: number): number {
    const min = Math.floor(minInclusive);
    const max = Math.floor(maxInclusive);
    if (max < min) {
      return min;
    }

    const range = max - min + 1;
    const unbiasedLimit = Math.floor(UINT32_RANGE / range) * range;
    let value = SecureRandomService.nextUInt32();
    while (value >= unbiasedLimit) {
      value = SecureRandomService.nextUInt32();
    }

    return min + value % range;
  }

  private static nextUInt32(): number {
    try {
      const bytes = cryptoFramework.createRandom().generateRandomSync(4).data;
      return SecureRandomService.bytesToUInt32(bytes);
    } catch (err) {
      return SecureRandomService.bytesToUInt32(util.generateRandomBinaryUUID(false));
    }
  }

  private static bytesToUInt32(bytes: Uint8Array): number {
    return (((bytes[0] * 256 + bytes[1]) * 256 + bytes[2]) * 256 + bytes[3]);
  }

  private static padLeft(value: string, length: number): string {
    let result = value;
    while (result.length < length) {
      result = `0${result}`;
    }

    return result;
  }
}
