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
