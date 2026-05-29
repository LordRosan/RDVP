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

test('authenticates and queries device archive by code', async () => {
  await withClient(async (client) => {
    const token = await client.login('reporter');
    const response = await client.request('GET', '/api/v1/devices/by-code/RDVP-DEVICE-0001', undefined, token);

    assert.equal(response.status, 200);
    assert.equal(response.body.success, true);
    assert.equal(response.body.data.deviceCode, 'RDVP-DEVICE-0001');
    assert.equal(response.body.data.status, 'NORMAL');
  });
});

test('verifies signed QR content and rejects tampered signatures', async () => {
  await withClient(async (client) => {
    const token = await client.login('reporter');
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

test('locks device archive changes until review and enforces freeze after approval', async () => {
  await withClient(async (client) => {
    const reporterToken = await client.login('reporter');
    const adminToken = await client.login('admin');

    const device = await client.request('GET', '/api/v1/devices/by-code/RDVP-DEVICE-0001', undefined, reporterToken);
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
    }, reporterToken);
    assert.equal(changeRequest.status, 201);
    assert.equal(changeRequest.body.data.status, 'PENDING_REVIEW');

    const lockedDevice = await client.request('GET', '/api/v1/devices/by-code/RDVP-DEVICE-0001', undefined, reporterToken);
    assert.equal(lockedDevice.body.data.status, 'CHANGE_PENDING_REVIEW');
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
    }, reporterToken);
    assert.equal(duplicate.status, 409);
    assert.equal(duplicate.body.error.code, 'DEVICE_CHANGE_LOCKED');

    const review = await client.request('POST', `/api/v1/device-change-requests/${changeRequest.body.data.id}/review`, {
      decision: 'APPROVED',
      reviewComment: 'Archive evidence is sufficient.'
    }, adminToken);
    assert.equal(review.status, 200);
    assert.equal(review.body.data.status, 'APPROVED');
    assert.ok(typeof review.body.data.freezeUntil === 'string');

    const updatedDevice = await client.request('GET', '/api/v1/devices/by-code/RDVP-DEVICE-0001', undefined, reporterToken);
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
    }, reporterToken);
    assert.equal(frozen.status, 409);
    assert.equal(frozen.body.error.code, 'DEVICE_CHANGE_FROZEN');
  });
});

test('creates a fault report and prevents duplicate task acceptance', async () => {
  await withClient(async (client) => {
    const reporterToken = await client.login('reporter');
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
    }, reporterToken);

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
    const reporterToken = await client.login('reporter');
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
    }, reporterToken);
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

    const device = await client.request('GET', '/api/v1/devices/by-code/RDVP-DEVICE-0003', undefined, reporterToken);
    assert.equal(device.status, 200);
    assert.equal(device.body.data.status, 'NORMAL');
  });
});

test('records audit logs for key workflow operations', async () => {
  await withClient(async (client) => {
    const reporterToken = await client.login('reporter');
    const adminToken = await client.login('admin');

    const created = await client.request('POST', '/api/v1/fault-reports', {
      deviceCode: 'RDVP-DEVICE-0001',
      faultType: 'OPERATION_ABNORMAL',
      severity: 'MINOR',
      occurredAt: '2026-05-29T08:00:00.000Z',
      description: 'Minor abnormal vibration detected.'
    }, reporterToken);
    assert.equal(created.status, 201);

    const auditLogs = await client.request('GET', '/api/v1/audit-logs', undefined, adminToken);
    assert.equal(auditLogs.status, 200);
    assert.ok(auditLogs.body.data.items.some((item: any) => item.action === 'AUTH_LOGIN'));
    assert.ok(auditLogs.body.data.items.some((item: any) => item.action === 'FAULT_REPORT'));
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
