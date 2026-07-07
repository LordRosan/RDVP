import { abilityAccessCtrl, Context, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';

const PRECISE_LOCATION_PERMISSION: Permissions = 'ohos.permission.LOCATION';
const APPROXIMATE_LOCATION_PERMISSION: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION';
const LOCATION_PERMISSIONS: Permissions[] = [
  PRECISE_LOCATION_PERMISSION,
  APPROXIMATE_LOCATION_PERMISSION
];
const CURRENT_LOCATION_TIMEOUT_MS = 8000;
const LOCATION_MAX_ACCURACY_METERS = 500;
const LOCATION_PERMISSION_DENIED_CODE = '201';
const LOCATION_CAPABILITY_UNSUPPORTED_CODE = '801';
const LOCATION_SERVICE_UNAVAILABLE_CODE = '3301000';
const LOCATION_SWITCH_OFF_CODE = '3301100';

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

export interface LocationErrorLike {
  code?: number | string;
  message?: string;
}

export class LocationService {
  static async resolveCurrentLocation(context: Context | undefined): Promise<LocationResolutionResult> {
    if (context === undefined) {
      return LocationService.createFailureResult(UiFeedbackService.operationUnavailable('定位'));
    }

    if (!LocationService.isSystemLocationEnabled()) {
      return LocationService.createFailureResult(LocationService.formatLocationSwitchOffMessage());
    }

    const permission = await LocationService.requestLocationPermission(context);
    if (!permission.granted) {
      return LocationService.createFailureResult(LocationService.formatLocationPermissionDeniedMessage());
    }

    try {
      const request = LocationService.createCurrentLocationRequest(permission.preciseGranted);
      const location = await geoLocationManager.getCurrentLocation(request);
      const coordinates = LocationService.createCoordinatesFromValues(
        location.longitude,
        location.latitude,
        location.accuracy,
        location.timeStamp
      );
      if (coordinates === undefined) {
        return LocationService.createFailureResult(LocationService.formatLocationFailedMessage());
      }

      return {
        success: true,
        message: UiFeedbackService.operationSuccess('定位'),
        coordinates
      };
    } catch (err) {
      const lastKnownCoordinates = LocationService.resolveLastKnownCoordinates(err as LocationErrorLike);
      if (lastKnownCoordinates !== undefined) {
        return {
          success: true,
          message: UiFeedbackService.operationSuccess('定位'),
          coordinates: lastKnownCoordinates
        };
      }

      return LocationService.createFailureResult(LocationService.formatLocationErrorMessage(err as LocationErrorLike));
    }
  }

  static createCoordinatesFromValues(
    longitude: number,
    latitude: number,
    accuracy: number | undefined,
    timeStamp: number | undefined
  ): LocationCoordinates | undefined {
    if (!LocationService.isValidCoordinate(longitude, -180, 180) ||
      !LocationService.isValidCoordinate(latitude, -90, 90)) {
      return undefined;
    }

    return {
      longitude,
      latitude,
      accuracy: LocationService.normalizeAccuracy(accuracy),
      locatedAt: LocationService.formatLocatedAt(timeStamp)
    };
  }

  static formatLocationErrorMessage(error: LocationErrorLike | undefined): string {
    const code = LocationService.resolveErrorCode(error);
    if (code === LOCATION_SWITCH_OFF_CODE) {
      return LocationService.formatLocationSwitchOffMessage();
    }

    if (code === LOCATION_PERMISSION_DENIED_CODE) {
      return LocationService.formatLocationPermissionDeniedMessage();
    }

    if (code === LOCATION_CAPABILITY_UNSUPPORTED_CODE) {
      return '当前设备定位能力不可用';
    }

    if (code === LOCATION_SERVICE_UNAVAILABLE_CODE) {
      return '当前设备定位服务不可用';
    }

    return LocationService.formatLocationFailedMessage();
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
      priority: preciseGranted ? geoLocationManager.LocationRequestPriority.FIRST_FIX :
      geoLocationManager.LocationRequestPriority.LOW_POWER,
      scenario: geoLocationManager.LocationRequestScenario.DAILY_LIFE_SERVICE,
      maxAccuracy: LOCATION_MAX_ACCURACY_METERS,
      timeoutMs: CURRENT_LOCATION_TIMEOUT_MS
    };
  }

  private static resolveLastKnownCoordinates(error: LocationErrorLike): LocationCoordinates | undefined {
    if (LocationService.isTerminalLocationError(error)) {
      return undefined;
    }

    try {
      const location = geoLocationManager.getLastLocation();
      return LocationService.createCoordinatesFromValues(
        location.longitude,
        location.latitude,
        location.accuracy,
        location.timeStamp
      );
    } catch (err) {
      return undefined;
    }
  }

  private static isTerminalLocationError(error: LocationErrorLike): boolean {
    const code = LocationService.resolveErrorCode(error);
    return code === LOCATION_SWITCH_OFF_CODE ||
      code === LOCATION_PERMISSION_DENIED_CODE ||
      code === LOCATION_CAPABILITY_UNSUPPORTED_CODE;
  }

  private static isSystemLocationEnabled(): boolean {
    try {
      return geoLocationManager.isLocationEnabled();
    } catch (err) {
      return true;
    }
  }

  private static isValidCoordinate(value: number, min: number, max: number): boolean {
    return value === value && value >= min && value <= max;
  }

  private static normalizeAccuracy(accuracy: number | undefined): number {
    if (accuracy === undefined || accuracy !== accuracy || accuracy < 0) {
      return 0;
    }

    return accuracy;
  }

  private static formatLocatedAt(timeStamp: number | undefined): string {
    if (timeStamp === undefined || timeStamp !== timeStamp || timeStamp <= 0) {
      return new Date().toISOString();
    }

    return new Date(timeStamp).toISOString();
  }

  private static createFailureResult(message: string): LocationResolutionResult {
    return {
      success: false,
      message
    };
  }

  private static resolveErrorCode(error: LocationErrorLike | undefined): string {
    if (error === undefined || error.code === undefined) {
      return '';
    }

    return `${error.code}`;
  }

  private static formatLocationSwitchOffMessage(): string {
    return '请先开启系统定位服务';
  }

  private static formatLocationPermissionDeniedMessage(): string {
    return '请允许定位权限';
  }

  private static formatLocationFailedMessage(): string {
    return '定位失败，请稍后重试';
  }
}
