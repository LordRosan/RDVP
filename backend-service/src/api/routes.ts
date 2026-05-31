import { IncomingMessage, ServerResponse } from 'node:http';
import { AppContext } from '../application/AppContext.js';
import { badRequest, notFound } from '../domain/errors.js';
import { DeviceChangeValue } from '../domain/models/entities.js';
import {
  ChangeRequestStatus,
  FaultSeverity,
  FaultType,
  PermissionCode,
  ReinspectionResult,
  RepairReportResult,
  RepairTaskStatus,
  VerificationResult
} from '../domain/models/enums.js';
import { createRequestContext, readJsonBody, sendError, sendSuccess } from './http.js';

interface LoginBody {
  username?: string;
  password?: string;
}

interface QrVerifyBody {
  qrContent?: string;
  scanLocation?: {
    longitude: number;
    latitude: number;
  };
  scannedAt?: string;
}

interface DeviceChangeRequestBody {
  deviceId?: string;
  reason?: string;
  changes?: Record<string, DeviceChangeValue>;
}

interface DeviceVerificationBody {
  result?: string;
  description?: string;
  remark?: string;
  verifiedAt?: string;
  location?: {
    longitude: number;
    latitude: number;
  };
}

interface DeviceChangeReviewBody {
  decision?: string;
  reviewComment?: string;
}

interface FaultReportBody {
  deviceCode?: string;
  faultType?: string;
  severity?: string;
  occurredAt?: string;
  description?: string;
  sceneCondition?: string;
  location?: {
    longitude: number;
    latitude: number;
  };
}

interface AcceptFaultBody {
  acceptedLocation?: {
    longitude: number;
    latitude: number;
  };
}

interface RepairReportBody {
  result?: string;
  repairedAt?: string;
  processDescription?: string;
  partsUsed?: string;
}

interface ReinspectionBody {
  result?: string;
  reinspectedAt?: string;
  description?: string;
}

export async function handleApiRequest(
  appContext: AppContext,
  request: IncomingMessage,
  response: ServerResponse
): Promise<void> {
  const requestContext = createRequestContext(request);

  try {
    const method = request.method ?? 'GET';
    const url = new URL(request.url ?? '/', 'http://localhost');
    if (method === 'GET' && (url.pathname === '/healthz' || url.pathname === '/readyz')) {
      sendSuccess(response, 200, createHealthPayload(appContext, url.pathname), requestContext.requestId);
      return;
    }

    const segments = url.pathname.split('/').filter((segment) => segment.length > 0);
    if (segments[0] !== 'api' || segments[1] !== 'v1') {
      throw notFound('NOT_FOUND', 'Route not found.');
    }

    const authorization = request.headers.authorization;

    if (method === 'POST' && segments[2] === 'auth' && segments[3] === 'login' && segments.length === 4) {
      const body = await readJsonBody<LoginBody>(request);
      const result = appContext.authService.login(
        requiredString(body.username, 'username'),
        requiredString(body.password, 'password'),
        requestContext.requestId
      );
      sendSuccess(response, 200, result, requestContext.requestId);
      return;
    }

    const actor = appContext.authService.authenticate(authorization);

    if (method === 'GET' && segments[2] === 'auth' && segments[3] === 'me' && segments.length === 4) {
      sendSuccess(response, 200, appContext.authService.toPublicUser(actor), requestContext.requestId);
      return;
    }

    if (method === 'GET' && segments[2] === 'devices' && segments[3] === 'by-code' && segments.length === 5) {
      appContext.authService.requirePermission(actor, PermissionCode.ArchiveDeviceRead);
      const deviceCode = requiredPathSegment(segments[4], 'deviceCode');
      sendSuccess(response, 200, appContext.deviceApplicationService.findByCode(deviceCode), requestContext.requestId);
      return;
    }

    if (method === 'GET' && segments[2] === 'devices' && segments.length === 4) {
      appContext.authService.requirePermission(actor, PermissionCode.ArchiveDeviceRead);
      const deviceId = requiredPathSegment(segments[3], 'deviceId');
      sendSuccess(response, 200, appContext.deviceApplicationService.findById(deviceId), requestContext.requestId);
      return;
    }

    if (method === 'POST' && segments[2] === 'device-qrcodes' && segments[3] === 'verify' && segments.length === 4) {
      appContext.authService.requirePermission(actor, PermissionCode.ArchiveDeviceRead);
      const body = await readJsonBody<QrVerifyBody>(request);
      const result = appContext.deviceApplicationService.verifyQrCode({
        qrContent: requiredString(body.qrContent, 'qrContent'),
        scanLocation: body.scanLocation,
        scannedAt: body.scannedAt,
        actor,
        requestId: requestContext.requestId
      });
      sendSuccess(response, 200, result, requestContext.requestId);
      return;
    }

    if (
      method === 'POST' &&
      segments[2] === 'devices' &&
      segments[4] === 'verification-records' &&
      segments.length === 5
    ) {
      appContext.authService.requirePermission(actor, PermissionCode.OpsDeviceVerify);
      const body = await readJsonBody<DeviceVerificationBody>(request);
      const result = appContext.deviceApplicationService.submitVerificationRecord({
        deviceId: requiredPathSegment(segments[3], 'deviceId'),
        result: requiredString(body.result, 'result') as VerificationResult,
        description: requiredString(body.description, 'description'),
        remark: body.remark,
        verifiedAt: body.verifiedAt,
        location: body.location,
        actor,
        requestId: requestContext.requestId
      });
      sendSuccess(response, 201, result, requestContext.requestId);
      return;
    }

    if (
      method === 'GET' &&
      segments[2] === 'devices' &&
      segments[4] === 'verification-records' &&
      segments.length === 5
    ) {
      appContext.authService.requirePermission(actor, PermissionCode.ArchiveDeviceRead);
      const result = appContext.deviceApplicationService.listVerificationRecords(
        requiredPathSegment(segments[3], 'deviceId')
      );
      sendSuccess(response, 200, { items: result, total: result.length }, requestContext.requestId);
      return;
    }

    if (method === 'POST' && segments[2] === 'device-change-requests' && segments.length === 3) {
      appContext.authService.requirePermission(actor, PermissionCode.ArchiveChangeRequestCreate);
      const body = await readJsonBody<DeviceChangeRequestBody>(request);
      const result = appContext.deviceChangeService.createChangeRequest({
        deviceId: requiredString(body.deviceId, 'deviceId'),
        reason: requiredString(body.reason, 'reason'),
        changes: requiredChanges(body.changes),
        actor,
        requestId: requestContext.requestId
      });
      sendSuccess(response, 201, result, requestContext.requestId);
      return;
    }

    if (method === 'GET' && segments[2] === 'device-change-requests' && segments.length === 3) {
      appContext.authService.requirePermission(actor, PermissionCode.MgmtArchiveChangeReview);
      const result = appContext.deviceChangeService.listChangeRequests({
        deviceCode: optionalString(url.searchParams.get('deviceCode')),
        status: optionalEnum<ChangeRequestStatus>(url.searchParams.get('status')),
        applicantId: optionalString(url.searchParams.get('applicantId'))
      });
      sendSuccess(response, 200, { items: result, total: result.length }, requestContext.requestId);
      return;
    }

    if (
      method === 'POST' &&
      segments[2] === 'device-change-requests' &&
      segments[4] === 'review' &&
      segments.length === 5
    ) {
      appContext.authService.requirePermission(actor, PermissionCode.MgmtArchiveChangeReview);
      const body = await readJsonBody<DeviceChangeReviewBody>(request);
      const result = appContext.deviceChangeService.reviewChangeRequest({
        requestId: requiredPathSegment(segments[3], 'requestId'),
        decision: requiredString(body.decision, 'decision') as 'APPROVED' | 'REJECTED',
        reviewComment: body.reviewComment,
        actor,
        requestIdHeader: requestContext.requestId
      });
      sendSuccess(response, 200, result, requestContext.requestId);
      return;
    }

    if (method === 'POST' && segments[2] === 'fault-reports' && segments.length === 3) {
      appContext.authService.requirePermission(actor, PermissionCode.OpsFaultReportCreate);
      const body = await readJsonBody<FaultReportBody>(request);
      const result = appContext.faultWorkflowService.createFaultReport({
        deviceCode: requiredString(body.deviceCode, 'deviceCode'),
        faultType: requiredString(body.faultType, 'faultType') as FaultType,
        severity: requiredString(body.severity, 'severity') as FaultSeverity,
        occurredAt: requiredString(body.occurredAt, 'occurredAt'),
        description: requiredString(body.description, 'description'),
        sceneCondition: body.sceneCondition,
        location: body.location,
        actor,
        requestId: requestContext.requestId
      });
      sendSuccess(response, 201, result, requestContext.requestId);
      return;
    }

    if (method === 'GET' && segments[2] === 'repair-tasks' && segments[3] === 'available' && segments.length === 4) {
      appContext.authService.requirePermission(actor, PermissionCode.OpsRepairTaskAccept);
      const result = appContext.faultWorkflowService.listAvailableRepairTasks({
        longitude: optionalNumber(url.searchParams.get('longitude')),
        latitude: optionalNumber(url.searchParams.get('latitude')),
        radiusKm: optionalNumber(url.searchParams.get('radiusKm')),
        severity: optionalEnum<FaultSeverity>(url.searchParams.get('severity'))
      });
      sendSuccess(response, 200, { items: result, total: result.length }, requestContext.requestId);
      return;
    }

    if (method === 'POST' && segments[2] === 'fault-reports' && segments[4] === 'accept' && segments.length === 5) {
      appContext.authService.requirePermission(actor, PermissionCode.OpsRepairTaskAccept);
      const body = await readJsonBody<AcceptFaultBody>(request);
      const result = appContext.faultWorkflowService.acceptFaultReport({
        faultReportId: requiredPathSegment(segments[3], 'faultReportId'),
        acceptedLocation: body.acceptedLocation,
        actor,
        requestId: requestContext.requestId
      });
      sendSuccess(response, 200, result, requestContext.requestId);
      return;
    }

    if (method === 'GET' && segments[2] === 'repair-tasks' && segments[3] === 'my' && segments.length === 4) {
      appContext.authService.requirePermission(actor, PermissionCode.OpsRepairReportCreate);
      const result = appContext.faultWorkflowService.listMyRepairTasks({
        actor,
        status: optionalEnum<RepairTaskStatus>(url.searchParams.get('status'))
      });
      sendSuccess(response, 200, { items: result, total: result.length }, requestContext.requestId);
      return;
    }

    if (
      method === 'POST' &&
      segments[2] === 'repair-tasks' &&
      segments[4] === 'repair-reports' &&
      segments.length === 5
    ) {
      appContext.authService.requirePermission(actor, PermissionCode.OpsRepairReportCreate);
      const body = await readJsonBody<RepairReportBody>(request);
      const result = appContext.faultWorkflowService.submitRepairReport({
        repairTaskId: requiredPathSegment(segments[3], 'repairTaskId'),
        result: requiredString(body.result, 'result') as RepairReportResult,
        repairedAt: requiredString(body.repairedAt, 'repairedAt'),
        processDescription: requiredString(body.processDescription, 'processDescription'),
        partsUsed: body.partsUsed,
        actor,
        requestId: requestContext.requestId
      });
      sendSuccess(response, 201, result, requestContext.requestId);
      return;
    }

    if (method === 'GET' && segments[2] === 'reinspections' && segments[3] === 'pending' && segments.length === 4) {
      appContext.authService.requirePermission(actor, PermissionCode.OpsReinspectionCreate);
      const result = appContext.faultWorkflowService.listPendingReinspections();
      sendSuccess(response, 200, { items: result, total: result.length }, requestContext.requestId);
      return;
    }

    if (
      method === 'POST' &&
      segments[2] === 'fault-reports' &&
      segments[4] === 'reinspection-records' &&
      segments.length === 5
    ) {
      appContext.authService.requirePermission(actor, PermissionCode.OpsReinspectionCreate);
      const body = await readJsonBody<ReinspectionBody>(request);
      const result = appContext.faultWorkflowService.submitReinspectionRecord({
        faultReportId: requiredPathSegment(segments[3], 'faultReportId'),
        result: requiredString(body.result, 'result') as ReinspectionResult,
        reinspectedAt: requiredString(body.reinspectedAt, 'reinspectedAt'),
        description: body.description,
        actor,
        requestId: requestContext.requestId
      });
      sendSuccess(response, 201, result, requestContext.requestId);
      return;
    }

    if (method === 'GET' && segments[2] === 'audit-logs' && segments.length === 3) {
      appContext.authService.requirePermission(actor, PermissionCode.MgmtAuditLogRead);
      const result = appContext.auditLogService.list();
      sendSuccess(response, 200, { items: result, total: result.length }, requestContext.requestId);
      return;
    }

    throw notFound('NOT_FOUND', 'Route not found.');
  } catch (error) {
    sendError(response, error, requestContext.requestId);
  }
}

function requiredPathSegment(value: string | undefined, name: string): string {
  if (value === undefined || value.trim().length === 0) {
    throw badRequest('BAD_REQUEST', `${name} is required.`);
  }

  return decodeURIComponent(value);
}

function requiredString(value: string | undefined, name: string): string {
  if (value === undefined || value.trim().length === 0) {
    throw badRequest('BAD_REQUEST', `${name} is required.`);
  }

  return value;
}

function optionalNumber(value: string | null): number | undefined {
  if (value === null || value.trim().length === 0) {
    return undefined;
  }

  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw badRequest('BAD_REQUEST', 'Numeric query parameter is invalid.');
  }

  return parsed;
}

function optionalString(value: string | null): string | undefined {
  if (value === null || value.trim().length === 0) {
    return undefined;
  }

  return value;
}

function optionalEnum<T extends string>(value: string | null): T | undefined {
  if (value === null || value.trim().length === 0) {
    return undefined;
  }

  return value as T;
}

function createHealthPayload(appContext: AppContext, pathname: string): Record<string, unknown> {
  return {
    status: pathname === '/readyz' ? 'ready' : 'ok',
    service: appContext.runtimeConfig.serviceName,
    version: appContext.runtimeConfig.serviceVersion,
    environment: appContext.runtimeConfig.environment,
    storageDriver: appContext.runtimeConfig.storageDriver,
    startedAt: appContext.startedAt
  };
}

function requiredChanges(value: Record<string, DeviceChangeValue> | undefined): Record<string, DeviceChangeValue> {
  if (value === undefined || Object.keys(value).length === 0) {
    throw badRequest('BAD_REQUEST', 'changes is required.');
  }

  return value;
}
