import asset from '@ohos.security.asset';
import util from '@ohos.util';

const SESSION_ASSET_ALIAS = 'rdvp_auth_session';

export class SecureSessionStorageService {
  static loadSessionText(): string | undefined {
    try {
      const records = asset.querySync(SecureSessionStorageService.createQueryMap());
      if (records.length === 0) {
        return undefined;
      }

      const secret = records[0].get(asset.Tag.SECRET);
      if (!(secret instanceof Uint8Array)) {
        return undefined;
      }

      return SecureSessionStorageService.decodeText(secret);
    } catch (err) {
      return undefined;
    }
  }

  static saveSessionText(sessionText: string): void {
    if (sessionText.length === 0) {
      SecureSessionStorageService.clearSessionText();
      return;
    }

    try {
      asset.addSync(SecureSessionStorageService.createSaveMap(sessionText));
    } catch (err) {
      SecureSessionStorageService.clearSessionText();
    }
  }

  static clearSessionText(): void {
    try {
      asset.removeSync(SecureSessionStorageService.createAliasMap());
    } catch (err) {
    }
  }

  private static createSaveMap(sessionText: string): asset.AssetMap {
    const attributes: asset.AssetMap = SecureSessionStorageService.createAliasMap();
    attributes.set(asset.Tag.SECRET, SecureSessionStorageService.encodeText(sessionText));
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    return attributes;
  }

  private static createQueryMap(): asset.AssetMap {
    const query: asset.AssetMap = SecureSessionStorageService.createAliasMap();
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    query.set(asset.Tag.RETURN_LIMIT, 1);
    return query;
  }

  private static createAliasMap(): asset.AssetMap {
    const attributes: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    attributes.set(asset.Tag.ALIAS, SecureSessionStorageService.encodeText(SESSION_ASSET_ALIAS));
    return attributes;
  }

  private static encodeText(text: string): Uint8Array {
    return util.TextEncoder.create('utf-8').encodeInto(text);
  }

  private static decodeText(bytes: Uint8Array): string {
    return util.TextDecoder.create('utf-8').decodeToString(bytes);
  }
}
