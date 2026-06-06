package com.rmf.rdvp.api.sync;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
class OfflineSyncControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void synchronizesFaultReportBatchIdempotently() throws Exception {
        String operatorToken = login("fieldoperator", "password");
        String maintainerToken = login("maintainer", "password");

        String response = syncFaultReportBatch(operatorToken, "batch-001", "record-001", "RDVP-DEVICE-0001")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.results[0].success").value(true))
                .andExpect(jsonPath("$.data.results[0].recordType").value("FAULT_REPORT_CREATE"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String firstServerRecordId = objectMapper.readTree(response)
                .path("data")
                .path("results")
                .path(0)
                .path("serverRecordId")
                .asText();

        String retryResponse = syncFaultReportBatch(operatorToken, "batch-001", "record-001", "RDVP-DEVICE-0001")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.results[0].serverRecordId").value(firstServerRecordId))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String retriedServerRecordId = objectMapper.readTree(retryResponse)
                .path("data")
                .path("results")
                .path(0)
                .path("serverRecordId")
                .asText();

        org.assertj.core.api.Assertions.assertThat(retriedServerRecordId).isEqualTo(firstServerRecordId);
        mockMvc.perform(get("/api/v1/repair-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + maintainerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].faultReportId").value(firstServerRecordId));
    }

    @Test
    void reusesClientRecordResultAcrossDifferentBatches() throws Exception {
        String operatorToken = login("fieldoperator", "password");

        String firstResponse = syncFaultReportBatch(operatorToken, "batch-001", "record-001", "RDVP-DEVICE-0001")
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String firstServerRecordId = resultAt(firstResponse, 0).path("serverRecordId").asText();

        syncFaultReportBatch(operatorToken, "batch-002", "record-001", "RDVP-DEVICE-0001")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.results[0].serverRecordId").value(firstServerRecordId));
    }

    @Test
    void reusesClientRecordResultWhenPayloadFieldOrderChanges() throws Exception {
        String operatorToken = login("fieldoperator", "password");

        String firstResponse = syncFaultReportBatch(operatorToken, "batch-001", "record-001", "RDVP-DEVICE-0001")
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String firstServerRecordId = resultAt(firstResponse, 0).path("serverRecordId").asText();

        syncBatch(operatorToken, validFaultReportBatchWithReorderedPayload("batch-002", "record-001", "RDVP-DEVICE-0001"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.results[0].serverRecordId").value(firstServerRecordId));
    }

    @Test
    void rejectsClientRecordReuseWithDifferentPayload() throws Exception {
        String operatorToken = login("fieldoperator", "password");

        syncFaultReportBatch(operatorToken, "batch-001", "record-001", "RDVP-DEVICE-0001")
                .andExpect(status().isOk());

        syncFaultReportBatch(operatorToken, "batch-002", "record-001", "RDVP-DEVICE-0002")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FAILED"))
                .andExpect(jsonPath("$.data.results[0].success").value(false))
                .andExpect(jsonPath("$.data.results[0].errorCode").value("OFFLINE_RECORD_CONFLICT"));
    }

    @Test
    void synchronizesDeviceVerificationRecord() throws Exception {
        String operatorToken = login("fieldoperator", "password");

        String response = syncBatch(operatorToken, validVerificationBatch("batch-verify-001", "record-verify-001", "RDVP-DEVICE-0002"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.results[0].success").value(true))
                .andExpect(jsonPath("$.data.results[0].recordType").value("DEVICE_VERIFICATION_CREATE"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);

        org.assertj.core.api.Assertions.assertThat(resultAt(response, 0).path("serverRecordId").asText())
                .startsWith("verification-");
    }

    @Test
    void synchronizesDeviceVerificationFaultReportRecord() throws Exception {
        String operatorToken = login("fieldoperator", "password");
        String maintainerToken = login("maintainer", "password");

        String response = syncBatch(
                        operatorToken,
                        validVerificationFaultReportBatch("batch-combined-001", "record-combined-001", "RDVP-DEVICE-0003"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.results[0].success").value(true))
                .andExpect(jsonPath("$.data.results[0].recordType").value("DEVICE_VERIFICATION_FAULT_REPORT_CREATE"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);

        org.assertj.core.api.Assertions.assertThat(resultAt(response, 0).path("serverRecordId").asText())
                .startsWith("verification-");
        mockMvc.perform(get("/api/v1/repair-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + maintainerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].deviceCode").value("RDVP-DEVICE-0003"));
    }

    @Test
    void synchronizesDeviceArchiveUpdateRequest() throws Exception {
        String operatorToken = login("fieldoperator", "password");
        String reviewerToken = login("deviceadmin", "password");

        String response = syncBatch(
                        operatorToken,
                        validArchiveUpdateRequestBatch("batch-archive-update-001", "record-archive-update-001"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.results[0].success").value(true))
                .andExpect(jsonPath("$.data.results[0].recordType").value("DEVICE_ARCHIVE_UPDATE_REQUEST_CREATE"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String requestId = resultAt(response, 0).path("serverRecordId").asText();

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + operatorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.changeState.locked").value(true))
                .andExpect(jsonPath("$.data.changeState.pendingRequestId").value(requestId));

        mockMvc.perform(get("/api/v1/device-change-requests?status=PENDING_REVIEW")
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(2))
                .andExpect(jsonPath("$.data.items[0].id").value(requestId))
                .andExpect(jsonPath("$.data.items[0].applicantName").value("现场运维人员"))
                .andExpect(jsonPath("$.data.items[0].initiatedAt").value("2026-06-04T08:00:00Z"))
                .andExpect(jsonPath("$.data.items[0].submittedAt").isString());
    }

    @Test
    void synchronizesDeviceArchiveCreateRequest() throws Exception {
        String token = login("deviceadmin", "password");

        String response = syncBatch(
                        token,
                        validArchiveCreateRequestBatch("batch-archive-create-001", "record-archive-create-001"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.results[0].success").value(true))
                .andExpect(jsonPath("$.data.results[0].recordType").value("DEVICE_ARCHIVE_CREATE_REQUEST_CREATE"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String requestId = resultAt(response, 0).path("serverRecordId").asText();

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0098")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("DEVICE_NOT_FOUND"));

        mockMvc.perform(get("/api/v1/device-change-requests?status=PENDING_REVIEW")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[0].id").value(requestId))
                .andExpect(jsonPath("$.data.items[0].deviceCode").value("RDVP-DEVICE-0098"));
    }

    @Test
    void synchronizesDeviceArchiveDeleteRequest() throws Exception {
        String token = login("deviceadmin", "password");

        String response = syncBatch(
                        token,
                        validArchiveDeleteRequestBatch("batch-archive-delete-001", "record-archive-delete-001"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.results[0].success").value(true))
                .andExpect(jsonPath("$.data.results[0].recordType").value("DEVICE_ARCHIVE_DELETE_REQUEST_CREATE"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String requestId = resultAt(response, 0).path("serverRecordId").asText();

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.changeState.locked").value(true))
                .andExpect(jsonPath("$.data.changeState.pendingRequestId").value(requestId));
    }

    @Test
    void rejectsConflictingDeviceArchiveOfflineRequestsInSameBatch() throws Exception {
        String token = login("fieldoperator", "password");

        syncBatch(token, conflictingArchiveUpdateRequestBatch())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PARTIALLY_FAILED"))
                .andExpect(jsonPath("$.data.results[0].success").value(true))
                .andExpect(jsonPath("$.data.results[1].success").value(false))
                .andExpect(jsonPath("$.data.results[1].errorCode").value("DEVICE_CHANGE_LOCKED"));
    }

    @Test
    void returnsPartialFailureForMixedBatch() throws Exception {
        String operatorToken = login("fieldoperator", "password");

        syncBatch(operatorToken, mixedVerificationAndInvalidFaultBatch())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PARTIALLY_FAILED"))
                .andExpect(jsonPath("$.data.results[0].success").value(true))
                .andExpect(jsonPath("$.data.results[0].recordType").value("DEVICE_VERIFICATION_CREATE"))
                .andExpect(jsonPath("$.data.results[1].success").value(false))
                .andExpect(jsonPath("$.data.results[1].recordType").value("FAULT_REPORT_CREATE"))
                .andExpect(jsonPath("$.data.results[1].errorCode").value("DEVICE_CODE_INVALID"));
    }

    @Test
    void returnsPerRecordConflictWithoutFailingWholeRequest() throws Exception {
        String operatorToken = login("fieldoperator", "password");
        syncFaultReportBatch(operatorToken, "batch-001", "record-001", "RDVP-DEVICE-0001")
                .andExpect(status().isOk());

        syncFaultReportBatch(operatorToken, "batch-002", "record-002", "RDVP-DEVICE-0001")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FAILED"))
                .andExpect(jsonPath("$.data.results[0].success").value(false))
                .andExpect(jsonPath("$.data.results[0].errorCode").value("DEVICE_ACTIVE_FAULT_EXISTS"));
    }

    @Test
    void enforcesRecordPermissionInsideBatch() throws Exception {
        String readonlyToken = login("readonly", "password");

        syncFaultReportBatch(readonlyToken, "batch-001", "record-001", "RDVP-DEVICE-0001")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FAILED"))
                .andExpect(jsonPath("$.data.results[0].success").value(false))
                .andExpect(jsonPath("$.data.results[0].errorCode").value("FORBIDDEN"));
    }

    @Test
    void protectsOfflineSyncEndpoint() throws Exception {
        mockMvc.perform(post("/api/v1/sync/offline-records")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validFaultReportBatch("batch-001", "record-001", "RDVP-DEVICE-0001")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
    }

    @Test
    void listsOfflineSyncAuditRecordsForAuditor() throws Exception {
        String operatorToken = login("fieldoperator", "password");
        String auditorToken = login("auditor", "password");

        syncFaultReportBatch(operatorToken, "batch-audit-001", "record-audit-001", "RDVP-DEVICE-0001")
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/sync/offline-records/audit?page=1&pageSize=10")
                        .header("Authorization", "Bearer " + auditorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].clientBatchId").value("batch-audit-001"))
                .andExpect(jsonPath("$.data.items[0].clientRecordId").value("record-audit-001"))
                .andExpect(jsonPath("$.data.items[0].recordType").value("FAULT_REPORT_CREATE"))
                .andExpect(jsonPath("$.data.items[0].status").value("SUCCEEDED"))
                .andExpect(jsonPath("$.data.items[0].createdOfflineAt").value("2026-06-04T08:00:00Z"))
                .andExpect(jsonPath("$.data.items[0].submittedAt").isString())
                .andExpect(jsonPath("$.data.items[0].processedAt").isString());
    }

    @Test
    void protectsOfflineSyncAuditEndpoint() throws Exception {
        String readonlyToken = login("readonly", "password");

        mockMvc.perform(get("/api/v1/sync/offline-records/audit")
                        .header("Authorization", "Bearer " + readonlyToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
    }

    private org.springframework.test.web.servlet.ResultActions syncFaultReportBatch(
            String token,
            String batchId,
            String recordId,
            String deviceCode) throws Exception {
        return mockMvc.perform(post("/api/v1/sync/offline-records")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(validFaultReportBatch(batchId, recordId, deviceCode)));
    }

    private org.springframework.test.web.servlet.ResultActions syncBatch(
            String token,
            String content) throws Exception {
        return mockMvc.perform(post("/api/v1/sync/offline-records")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(content));
    }

    private String validFaultReportBatch(String batchId, String recordId, String deviceCode) {
        return """
                {
                  "clientBatchId": "%s",
                  "records": [
                    {
                      "clientRecordId": "%s",
                      "recordType": "FAULT_REPORT_CREATE",
                      "createdOfflineAt": "2026-06-04T08:00:00Z",
                      "payload": {
                        "deviceCode": "%s",
                        "faultType": "ENERGY_FAULT",
                        "severity": "GENERAL",
                        "occurredAt": "2026-06-04T07:50:00Z",
                        "description": "Offline queued fault report.",
                        "sceneCondition": "Submitted after network recovery."
                      }
                    }
                  ]
                }
                """.formatted(batchId, recordId, deviceCode);
    }

    private String validFaultReportBatchWithReorderedPayload(String batchId, String recordId, String deviceCode) {
        return """
                {
                  "records": [
                    {
                      "payload": {
                        "sceneCondition": "Submitted after network recovery.",
                        "description": "Offline queued fault report.",
                        "occurredAt": "2026-06-04T07:50:00Z",
                        "severity": "GENERAL",
                        "faultType": "ENERGY_FAULT",
                        "deviceCode": "%s"
                      },
                      "createdOfflineAt": "2026-06-04T08:00:00Z",
                      "recordType": "FAULT_REPORT_CREATE",
                      "clientRecordId": "%s"
                    }
                  ],
                  "clientBatchId": "%s"
                }
                """.formatted(deviceCode, recordId, batchId);
    }

    private String validVerificationBatch(String batchId, String recordId, String deviceCode) {
        return """
                {
                  "clientBatchId": "%s",
                  "records": [
                    {
                      "clientRecordId": "%s",
                      "recordType": "DEVICE_VERIFICATION_CREATE",
                      "createdOfflineAt": "2026-06-04T08:00:00Z",
                      "payload": {
                        "deviceCode": "%s",
                        "result": "NORMAL",
                        "verifiedAt": "2026-06-04T07:50:00Z",
                        "description": "Offline queued device verification.",
                        "remark": "Synced after network recovery."
                      }
                    }
                  ]
                }
                """.formatted(batchId, recordId, deviceCode);
    }

    private String validVerificationFaultReportBatch(String batchId, String recordId, String deviceCode) {
        return """
                {
                  "clientBatchId": "%s",
                  "records": [
                    {
                      "clientRecordId": "%s",
                      "recordType": "DEVICE_VERIFICATION_FAULT_REPORT_CREATE",
                      "createdOfflineAt": "2026-06-04T08:00:00Z",
                      "payload": {
                        "deviceCode": "%s",
                        "result": "ABNORMAL",
                        "verifiedAt": "2026-06-04T07:50:00Z",
                        "description": "Offline queued abnormal verification.",
                        "remark": "Fault report is submitted together.",
                        "faultType": "COMMUNICATION_FAULT",
                        "severity": "GENERAL",
                        "occurredAt": "2026-06-04T07:45:00Z",
                        "faultDescription": "Device communication is unstable.",
                        "sceneCondition": "Intermittent packet loss observed on site."
                      }
                    }
                  ]
                }
                """.formatted(batchId, recordId, deviceCode);
    }

    private String validArchiveUpdateRequestBatch(String batchId, String recordId) {
        return """
                {
                  "clientBatchId": "%s",
                  "records": [
                    {
                      "clientRecordId": "%s",
                      "recordType": "DEVICE_ARCHIVE_UPDATE_REQUEST_CREATE",
                      "createdOfflineAt": "2026-06-04T08:00:00Z",
                      "payload": {
                        "deviceId": "device-local-0001",
                        "deviceCode": "RDVP-DEVICE-0001",
                        "reason": "离线巡检后修正设备名称。",
                        "changes": [
                          {
                            "field": "name",
                            "oldValue": "冷却泵A-01",
                            "newValue": "冷却泵A-02"
                          }
                        ]
                      }
                    }
                  ]
                }
                """.formatted(batchId, recordId);
    }

    private String validArchiveCreateRequestBatch(String batchId, String recordId) {
        return """
                {
                  "clientBatchId": "%s",
                  "records": [
                    {
                      "clientRecordId": "%s",
                      "recordType": "DEVICE_ARCHIVE_CREATE_REQUEST_CREATE",
                      "createdOfflineAt": "2026-06-04T08:00:00Z",
                      "payload": {
                        "deviceCode": "RDVP-DEVICE-0098",
                        "reason": "离线完成新设备建档信息采集。",
                        "changes": [
                          {
                            "field": "name",
                            "newValue": "巡检网关G-98"
                          },
                          {
                            "field": "model",
                            "newValue": "IG-980"
                          },
                          {
                            "field": "manufacturer",
                            "newValue": "北方设备"
                          },
                          {
                            "field": "location.address",
                            "newValue": "九号厂房巡检区"
                          }
                        ]
                      }
                    }
                  ]
                }
                """.formatted(batchId, recordId);
    }

    private String validArchiveDeleteRequestBatch(String batchId, String recordId) {
        return """
                {
                  "clientBatchId": "%s",
                  "records": [
                    {
                      "clientRecordId": "%s",
                      "recordType": "DEVICE_ARCHIVE_DELETE_REQUEST_CREATE",
                      "createdOfflineAt": "2026-06-04T08:00:00Z",
                      "payload": {
                        "deviceId": "device-local-0001",
                        "deviceCode": "RDVP-DEVICE-0001",
                        "reason": "离线确认设备退役。"
                      }
                    }
                  ]
                }
                """.formatted(batchId, recordId);
    }

    private String conflictingArchiveUpdateRequestBatch() {
        return """
                {
                  "clientBatchId": "batch-archive-update-conflict-001",
                  "records": [
                    {
                      "clientRecordId": "record-archive-update-conflict-001",
                      "recordType": "DEVICE_ARCHIVE_UPDATE_REQUEST_CREATE",
                      "createdOfflineAt": "2026-06-04T08:00:00Z",
                      "payload": {
                        "deviceId": "device-local-0001",
                        "deviceCode": "RDVP-DEVICE-0001",
                        "reason": "第一次离线档案修正。",
                        "changes": [
                          {
                            "field": "name",
                            "oldValue": "冷却泵A-01",
                            "newValue": "冷却泵A-02"
                          }
                        ]
                      }
                    },
                    {
                      "clientRecordId": "record-archive-update-conflict-002",
                      "recordType": "DEVICE_ARCHIVE_UPDATE_REQUEST_CREATE",
                      "createdOfflineAt": "2026-06-04T08:02:00Z",
                      "payload": {
                        "deviceId": "device-local-0001",
                        "deviceCode": "RDVP-DEVICE-0001",
                        "reason": "第二次离线档案修正。",
                        "changes": [
                          {
                            "field": "model",
                            "oldValue": "CP-A100",
                            "newValue": "CP-A101"
                          }
                        ]
                      }
                    }
                  ]
                }
                """;
    }

    private String mixedVerificationAndInvalidFaultBatch() {
        return """
                {
                  "clientBatchId": "batch-mixed-001",
                  "records": [
                    {
                      "clientRecordId": "record-mixed-001",
                      "recordType": "DEVICE_VERIFICATION_CREATE",
                      "createdOfflineAt": "2026-06-04T08:00:00Z",
                      "payload": {
                        "deviceCode": "RDVP-DEVICE-0002",
                        "result": "NORMAL",
                        "verifiedAt": "2026-06-04T07:50:00Z",
                        "description": "Offline queued device verification.",
                        "remark": "Synced after network recovery."
                      }
                    },
                    {
                      "clientRecordId": "record-mixed-002",
                      "recordType": "FAULT_REPORT_CREATE",
                      "createdOfflineAt": "2026-06-04T08:01:00Z",
                      "payload": {
                        "deviceCode": "invalid-device",
                        "faultType": "ENERGY_FAULT",
                        "severity": "GENERAL",
                        "occurredAt": "2026-06-04T07:50:00Z",
                        "description": "Offline queued fault report.",
                        "sceneCondition": "Submitted after network recovery."
                      }
                    }
                  ]
                }
                """;
    }

    private JsonNode resultAt(String response, int index) throws Exception {
        return objectMapper.readTree(response).path("data").path("results").path(index);
    }

    private String login(String username, String password) throws Exception {
        String response = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "username": "%s",
                                  "password": "%s",
                                  "clientDeviceId": "test-device"
                                }
                                """.formatted(username, password)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);

        JsonNode root = objectMapper.readTree(response);
        return root.path("data").path("accessToken").asText();
    }
}
