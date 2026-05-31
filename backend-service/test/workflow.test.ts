import assert from 'node:assert/strict';
import { Server } from 'node:http';
import { AddressInfo } from 'node:net';
import test from 'node:test';
import { createDefaultAppContext, AppContext } from '../src/application/AppContext.js';
import { createHttpServer } from '../src/api/server.js';

interface TestClient {
  appContext: AppContext;
  request: (method: string, path: string, body?: unknown, token?: string) => Promise<{ status: number; body: any }>;
  login: (username: string) => Promise<string>;
}

test('exposes unauthenticated health and readiness probes', async () => {
  await withClient(async (client) => {
    const health = await client.request('GET', '/healthz');
    assert.equal(health.status, 200);
    assert.equal(health.body.success, true);
    assert.equal(health.body.data.status, 'ok');
    assert.equal(health.body.data.service, 'rdvp-backend-service');
    assert.equal(health.body.data.storageDriver, 'memory');

    const readiness = await client.request('GET', '/readyz');
    assert.equal(readiness.status, 200);
    assert.equal(readiness.body.data.status, 'ready');
  });
});

test('authenticates and queries device archive by code', async () => {
  await withClient(async (client) => {
    const token = await client.login('fieldoperator');
    const response = await client.request('GET', '/api/v1/devices/by-code/RDVP-DEVICE-0001', undefined, token);

    assert.equal(response.status, 200);
    assert.equal(response.body.success, true);
    assert.equal(response.body.data.deviceCode, 'RDVP-DEVICE-0001');
    assert.equal(response.body.data.status, 'NORMAL');
  });
});

test('verifies signed QR content and rejects tampered signatures', async () => {
  await withClient(async (client) => {
    const token = await client.login('fieldoperator');
    const qrContent = client.appContext.database.buildQrContentForDeviceCode('RDVP-DEVICE-0001');

    const validResponse = await client.request('POST', '/api/v1/device-qrcodes/verify', { qrContent }, token);
    assert.equal(validResponse.status, 200);
    assert.equal(validResponse.body.data.valid, true);
    assert.equal(validResponse.body.data.device.deviceCode, 'RDVP-DEVICE-0001');

    const tamperedQrContent = qrContent.replace(/[a-f0-9]{64}$/u, '0'.repeat(64));
    const invalidResponse = await client.request('POST', '/api/v1/device-qrcodes/verify', {
      qrContent: tamperedQrContent
    }, token);

    assert.equal(invalidResponse.status, 400);
    assert.equal(invalidResponse.body.success, false);
    assert.equal(invalidResponse.body.error.code, 'QR_CODE_SIGNATURE_INVALID');
  });
});

test('submits device verification record and updates last verification time', async () => {
  await withClient(async (client) => {
    const operatorToken = await client.login('fieldoperator');
    const device = await client.request('GET', '/api/v1/devices/by-code/RDVP-DEVICE-0001', undefined, operatorToken);
    assert.equal(device.status, 200);

    const verifiedAt = '2026-05-29T09:30:00.000Z';
    const created = await client.request('POST', `/api/v1/devices/${device.body.data.id}/verification-records`, {
      result: 'NORMAL',
      description: 'Device is operating normally during site verification.',
      remark: 'No abnormal noise.',
      verifiedAt
    }, operatorToken);

    assert.equal(created.status, 201);
    assert.equal(created.body.data.deviceId, device.body.data.id);
    assert.equal(created.body.data.result, 'NORMAL');
    assert.equal(created.body.data.verifiedAt, verifiedAt);

    const records = await client.request('GET', `/api/v1/devices/${device.body.data.id}/verification-records`, undefined, operatorToken);
    assert.equal(records.status, 200);
    assert.equal(records.body.data.total, 1);

    const updatedDevice = await client.request('GET', '/api/v1/devices/by-code/RDVP-DEVICE-0001', undefined, operatorToken);
    assert.equal(updatedDevice.body.data.lastVerificationTime, verifiedAt);
  });
});

test('locks device archive changes until review and enforces freeze after approval', async () => {
  await withClient(async (client) => {
    const operatorToken = await client.login('fieldoperator');
    const adminToken = await client.login('admin');

    const device = await client.request('GET', '/api/v1/devices/by-code/RDVP-DEVICE-0001', undefined, operatorToken);
    assert.equal(device.status, 200);

    const changeRequest = await client.request('POST', '/api/v1/device-change-requests', {
      deviceId: device.body.data.id,
      reason: 'Archive name is outdated.',
      changes: {
        name: {
          oldValue: device.body.data.name,
          newValue: 'Cooling Pump A-01 Updated'
        }
      }
    }, operatorToken);
    assert.equal(changeRequest.status, 201);
    assert.equal(changeRequest.body.data.status, 'PENDING_REVIEW');

    const lockedDevice = await client.request('GET', '/api/v1/devices/by-code/RDVP-DEVICE-0001', undefined, operatorToken);
    assert.equal(lockedDevice.body.data.status, device.body.data.status);
    assert.equal(lockedDevice.body.data.changeState.locked, true);

    const duplicate = await client.request('POST', '/api/v1/device-change-requests', {
      deviceId: device.body.data.id,
      reason: 'Try another change.',
      changes: {
        model: {
          oldValue: device.body.data.model,
          newValue: 'CP-1000-B'
        }
      }
    }, operatorToken);
    assert.equal(duplicate.status, 409);
    assert.equal(duplicate.body.error.code, 'DEVICE_CHANGE_LOCKED');

    const review = await client.request('POST', `/api/v1/device-change-requests/${changeRequest.body.data.id}/review`, {
      decision: 'APPROVED',
      reviewComment: 'Archive evidence is sufficient.'
    }, adminToken);
    assert.equal(review.status, 200);
    assert.equal(review.body.data.status, 'APPROVED');
    assert.ok(typeof review.body.data.freezeUntil === 'string');

    const updatedDevice = await client.request('GET', '/api/v1/devices/by-code/RDVP-DEVICE-0001', undefined, operatorToken);
    assert.equal(updatedDevice.body.data.name, 'Cooling Pump A-01 Updated');
    assert.equal(updatedDevice.body.data.status, 'NORMAL');
    assert.equal(updatedDevice.body.data.changeState.locked, false);

    const frozen = await client.request('POST', '/api/v1/device-change-requests', {
      deviceId: device.body.data.id,
      reason: 'Try change during freeze.',
      changes: {
        model: {
          oldValue: device.body.data.model,
          newValue: 'CP-1000-C'
        }
      }
    }, operatorToken);
    assert.equal(frozen.status, 409);
    assert.equal(frozen.body.error.code, 'DEVICE_CHANGE_FROZEN');
  });
});

test('allows device administrators to list seeded pending archive changes', async () => {
  await withClient(async (client) => {
    const deviceAdminToken = await client.login('deviceadmin');
    const response = await client.request('GET', '/api/v1/device-change-requests?status=PENDING_REVIEW', undefined,
      deviceAdminToken);

    assert.equal(response.status, 200);
    assert.equal(response.body.data.total, 1);
    assert.equal(response.body.data.items[0].id, 'DCR-LOCAL-0002');
    assert.equal(response.body.data.items[0].deviceCode, 'RDVP-DEVICE-0002');
  });
});

test('creates a fault report and prevents duplicate task acceptance', async () => {
  await withClient(async (client) => {
    const operatorToken = await client.login('fieldoperator');
    const maintainerToken = await client.login('maintainer');

    const created = await client.request('POST', '/api/v1/fault-reports', {
      deviceCode: 'RDVP-DEVICE-0001',
      faultType: 'ENERGY_FAULT',
      severity: 'GENERAL',
      occurredAt: '2026-05-29T04:00:00.000Z',
      description: 'Power supply is unstable.',
      sceneCondition: 'The site reduced load.',
      location: {
        longitude: 114.1694,
        latitude: 22.3193
      }
    }, operatorToken);

    assert.equal(created.status, 201);
    assert.equal(created.body.data.status, 'PENDING_ACCEPTANCE');

    const available = await client.request('GET', '/api/v1/repair-tasks/available?longitude=114.1694&latitude=22.3193&radiusKm=10', undefined, maintainerToken);
    assert.equal(available.status, 200);
    assert.ok(available.body.data.items.some((item: any) => item.faultReportId === created.body.data.id));

    const accepted = await client.request('POST', `/api/v1/fault-reports/${created.body.data.id}/accept`, {
      acceptedLocation: {
        longitude: 114.1694,
        latitude: 22.3193
      }
    }, maintainerToken);
    assert.equal(accepted.status, 200);
    assert.equal(accepted.body.data.status, 'ACCEPTED');

    const duplicate = await client.request('POST', `/api/v1/fault-reports/${created.body.data.id}/accept`, {}, maintainerToken);
    assert.equal(duplicate.status, 409);
    assert.equal(duplicate.body.error.code, 'FAULT_ALREADY_ACCEPTED');
  });
});

test('routes severe repair through reinspection before restoring device status', async () => {
  await withClient(async (client) => {
    const operatorToken = await client.login('fieldoperator');
    const maintainerToken = await client.login('maintainer');
    const reinspectorToken = await client.login('reinspector');

    const created = await client.request('POST', '/api/v1/fault-reports', {
      deviceCode: 'RDVP-DEVICE-0003',
      faultType: 'COMMUNICATION_FAULT',
      severity: 'SEVERE',
      occurredAt: '2026-05-29T05:00:00.000Z',
      description: 'Communication gateway frequently disconnects.',
      sceneCondition: 'Local fallback mode is enabled.',
      location: {
        longitude: 114.1662,
        latitude: 22.321
      }
    }, operatorToken);
    assert.equal(created.status, 201);

    const accepted = await client.request('POST', `/api/v1/fault-reports/${created.body.data.id}/accept`, {}, maintainerToken);
    assert.equal(accepted.status, 200);

    const repairReport = await client.request('POST', `/api/v1/repair-tasks/${accepted.body.data.repairTaskId}/repair-reports`, {
      result: 'REPAIRED',
      repairedAt: '2026-05-29T06:00:00.000Z',
      processDescription: 'Replaced communication module and completed local validation.',
      partsUsed: 'Communication module x1'
    }, maintainerToken);
    assert.equal(repairReport.status, 201);
    assert.equal(repairReport.body.data.requiresReinspection, true);
    assert.equal(repairReport.body.data.nextStatus, 'PENDING_REINSPECTION');

    const repeatedRepairReport = await client.request('POST',
      `/api/v1/repair-tasks/${accepted.body.data.repairTaskId}/repair-reports`, {
        result: 'REPAIRED',
        repairedAt: '2026-05-29T06:10:00.000Z',
        processDescription: 'Repeated report submission should be rejected.',
        partsUsed: ''
      }, maintainerToken);
    assert.equal(repeatedRepairReport.status, 422);
    assert.equal(repeatedRepairReport.body.error.code, 'REPAIR_TASK_STATUS_INVALID');

    const myTasksAfterReport = await client.request('GET', '/api/v1/repair-tasks/my', undefined, maintainerToken);
    assert.equal(myTasksAfterReport.status, 200);
    assert.equal(myTasksAfterReport.body.data.items.some((item: any) => {
      return item.id === accepted.body.data.repairTaskId;
    }), false);

    const pending = await client.request('GET', '/api/v1/reinspections/pending', undefined, reinspectorToken);
    assert.equal(pending.status, 200);
    assert.ok(pending.body.data.items.some((item: any) => item.faultReportId === created.body.data.id));

    const reinspection = await client.request('POST', `/api/v1/fault-reports/${created.body.data.id}/reinspection-records`, {
      result: 'PASSED',
      reinspectedAt: '2026-05-29T07:00:00.000Z',
      description: 'Device status is stable after repair.'
    }, reinspectorToken);
    assert.equal(reinspection.status, 201);
    assert.equal(reinspection.body.data.nextFaultStatus, 'CLOSED');
    assert.equal(reinspection.body.data.nextDeviceStatus, 'NORMAL');

    const device = await client.request('GET', '/api/v1/devices/by-code/RDVP-DEVICE-0003', undefined, operatorToken);
    assert.equal(device.status, 200);
    assert.equal(device.body.data.status, 'NORMAL');
  });
});

test('records audit logs for key workflow operations', async () => {
  await withClient(async (client) => {
    const operatorToken = await client.login('fieldoperator');
    const adminToken = await client.login('admin');

    const created = await client.request('POST', '/api/v1/fault-reports', {
      deviceCode: 'RDVP-DEVICE-0001',
      faultType: 'OPERATION_ABNORMAL',
      severity: 'MINOR',
      occurredAt: '2026-05-29T08:00:00.000Z',
      description: 'Minor abnormal vibration detected.'
    }, operatorToken);
    assert.equal(created.status, 201);

    const auditLogs = await client.request('GET', '/api/v1/audit-logs', undefined, adminToken);
    assert.equal(auditLogs.status, 200);
    assert.ok(auditLogs.body.data.items.some((item: any) => item.action === 'AUTH_LOGIN'));
    assert.ok(auditLogs.body.data.items.some((item: any) => item.action === 'FAULT_REPORT'));
  });
});

test('enforces role permissions on management endpoints', async () => {
  await withClient(async (client) => {
    const operatorToken = await client.login('fieldoperator');
    const auditorToken = await client.login('auditor');

    const forbiddenAudit = await client.request('GET', '/api/v1/audit-logs', undefined, operatorToken);
    assert.equal(forbiddenAudit.status, 403);
    assert.equal(forbiddenAudit.body.error.code, 'FORBIDDEN');

    const allowedAudit = await client.request('GET', '/api/v1/audit-logs', undefined, auditorToken);
    assert.equal(allowedAudit.status, 200);
    assert.equal(allowedAudit.body.success, true);

    const forbiddenReviewList = await client.request('GET', '/api/v1/device-change-requests?status=PENDING_REVIEW',
      undefined, auditorToken);
    assert.equal(forbiddenReviewList.status, 403);
    assert.equal(forbiddenReviewList.body.error.code, 'FORBIDDEN');
  });
});

async function withClient(run: (client: TestClient) => Promise<void>): Promise<void> {
  const appContext = createDefaultAppContext();
  const server = createHttpServer(appContext);
  const baseUrl = await listen(server);

  const client: TestClient = {
    appContext,
    request: async (method, path, body, token) => {
      const headers: Record<string, string> = {
        accept: 'application/json'
      };
      if (body !== undefined) {
        headers['content-type'] = 'application/json';
      }
      if (token !== undefined) {
        headers.authorization = `Bearer ${token}`;
      }

      const response = await fetch(`${baseUrl}${path}`, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body)
      });

      return {
        status: response.status,
        body: await response.json()
      };
    },
    login: async (username) => {
      const response = await client.request('POST', '/api/v1/auth/login', {
        username,
        password: 'password'
      });
      assert.equal(response.status, 200);
      return response.body.data.accessToken;
    }
  };

  try {
    await run(client);
  } finally {
    await close(server);
  }
}

function listen(server: Server): Promise<string> {
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      const address = server.address() as AddressInfo;
      resolve(`http://127.0.0.1:${address.port}`);
    });
  });
}

function close(server: Server): Promise<void> {
  return new Promise((resolve, reject) => {
    server.close((error) => {
      if (error !== undefined) {
        reject(error);
        return;
      }
      resolve();
    });
  });
}
