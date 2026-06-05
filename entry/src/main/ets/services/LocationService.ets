import { abilityAccessCtrl, Context, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';

const PRECISE_LOCATION_PERMISSION: Permissions = 'ohos.permission.LOCATION';
const APPROXIMATE_LOCATION_PERMISSION: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION';
const LOCATION_PERMISSIONS: Permissions[] = [
  PRECISE_LOCATION_PERMISSION,
  APPROXIMATE_LOCATION_PERMISSION
];
const CURRENT_LOCATION_TIMEOUT_MS = 3000;
const LOCATION_MAX_ACCURACY_METERS = 500;

export interface LocationCoordinates {
  longitude: number;
  latitude: number;
  accuracy: number;
  locatedAt: string;
}

export interface LocationResolutionResult {
  success: boolean;
  message: string;
  coordinates?: LocationCoordinates;
}

interface LocationPermissionGrant {
  granted: boolean;
  preciseGranted: boolean;
}

export class LocationService {
  static async resolveCurrentLocation(context: Context | undefined): Promise<LocationResolutionResult> {
    if (context === undefined) {
      return LocationService.createFailureResult('无法获取页面上下文，已按未定位列表刷新');
    }

    const permission = await LocationService.requestLocationPermission(context);
    if (!permission.granted) {
      return LocationService.createFailureResult('未授权位置权限，已按未定位列表刷新');
    }

    try {
      const request = LocationService.createCurrentLocationRequest(permission.preciseGranted);
      const location = await geoLocationManager.getCurrentLocation(request);
      if (!LocationService.isValidCoordinate(location.longitude, -180, 180) ||
        !LocationService.isValidCoordinate(location.latitude, -90, 90)) {
        return LocationService.createFailureResult('当前位置无效，已按未定位列表刷新');
      }

      const coordinates: LocationCoordinates = {
        longitude: location.longitude,
        latitude: location.latitude,
        accuracy: location.accuracy,
        locatedAt: new Date().toISOString()
      };
      return {
        success: true,
        message: '已获取当前位置',
        coordinates
      };
    } catch (err) {
      return LocationService.createFailureResult('当前位置获取失败，已按未定位列表刷新');
    }
  }

  private static async requestLocationPermission(context: Context): Promise<LocationPermissionGrant> {
    try {
      const result = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(context, LOCATION_PERMISSIONS);
      let preciseGranted = false;
      let approximateGranted = false;
      for (let index = 0; index < result.permissions.length; index++) {
        const granted = result.authResults.length > index && result.authResults[index] === 0;
        if (result.permissions[index] === PRECISE_LOCATION_PERMISSION) {
          preciseGranted = granted;
        }
        if (result.permissions[index] === APPROXIMATE_LOCATION_PERMISSION) {
          approximateGranted = granted;
        }
      }

      return {
        granted: preciseGranted || approximateGranted,
        preciseGranted
      };
    } catch (err) {
      return {
        granted: false,
        preciseGranted: false
      };
    }
  }

  private static createCurrentLocationRequest(preciseGranted: boolean): geoLocationManager.CurrentLocationRequest {
    return {
      priority: preciseGranted ? geoLocationManager.LocationRequestPriority.ACCURACY :
      geoLocationManager.LocationRequestPriority.LOW_POWER,
      scenario: geoLocationManager.LocationRequestScenario.UNSET,
      maxAccuracy: LOCATION_MAX_ACCURACY_METERS,
      timeoutMs: CURRENT_LOCATION_TIMEOUT_MS
    };
  }

  private static isValidCoordinate(value: number, min: number, max: number): boolean {
    return value === value && value >= min && value <= max;
  }

  private static createFailureResult(message: string): LocationResolutionResult {
    return {
      success: false,
      message
    };
  }
}
