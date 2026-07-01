package com.rmf.rdvp.api.dashboard;

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
class DashboardControllerTests {

    private static final String VALID_QR_CONTENT =
            "RDVP:1:RDVP-DEVICE-0001:nonce-rdvp-device-0001:F36D5F8B2A520071A5955968704A6DD4017A01E6457F573527867E47813C2807";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void returnsDashboardStatsForAuthenticatedUser() throws Exception {
        String token = login("admin", "password");

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.archive.deviceTotal").value(3))
                .andExpect(jsonPath("$.data.archive.archiveCreates").value(0))
                .andExpect(jsonPath("$.data.archive.archiveDeletes").value(0))
                .andExpect(jsonPath("$.data.archive.archiveUpdates").value(0))
                .andExpect(jsonPath("$.data.archive.archiveQueries").value(0))
                .andExpect(jsonPath("$.data.archive.archiveExports").value(0))
                .andExpect(jsonPath("$.data.operations.taskPoolTotal").value(0))
                .andExpect(jsonPath("$.data.operations.verifications").value(0))
                .andExpect(jsonPath("$.data.operations.faultReports").value(0))
                .andExpect(jsonPath("$.data.operations.repairs").value(0))
                .andExpect(jsonPath("$.data.operations.reinspections").value(0))
                .andExpect(jsonPath("$.data.review.reviewedTotal").value(0))
                .andExpect(jsonPath("$.data.review.pendingArchiveReviews").value(1))
                .andExpect(jsonPath("$.data.review.pendingOperationsReviews").value(0))
                .andExpect(jsonPath("$.data.log.logTotal").value(1))
                .andExpect(jsonPath("$.data.log.archiveOperationLogs").value(1))
                .andExpect(jsonPath("$.data.log.archiveReviewLogs").value(0))
                .andExpect(jsonPath("$.data.log.operationsOperationLogs").value(0))
                .andExpect(jsonPath("$.data.log.operationsReviewLogs").value(0));
    }

    @Test
    void filtersDashboardStatsByCurrentUserPermissions() throws Exception {
        String operationsStaffToken = login("operator", "password");
        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + operationsStaffToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive").doesNotExist())
                .andExpect(jsonPath("$.data.operations.taskPoolTotal").value(0))
                .andExpect(jsonPath("$.data.operations.verifications").value(0))
                .andExpect(jsonPath("$.data.operations.faultReports").value(0))
                .andExpect(jsonPath("$.data.operations.repairs").value(0))
                .andExpect(jsonPath("$.data.operations.reinspections").value(0))
                .andExpect(jsonPath("$.data.log").doesNotExist())
                .andExpect(jsonPath("$.data.review").doesNotExist());

        String operationsAdminToken = login("operationsadmin", "password");
        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + operationsAdminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive").doesNotExist())
                .andExpect(jsonPath("$.data.operations.taskPoolTotal").value(0))
                .andExpect(jsonPath("$.data.log.archiveOperationLogs").doesNotExist())
                .andExpect(jsonPath("$.data.log.archiveReviewLogs").doesNotExist())
                .andExpect(jsonPath("$.data.log.operationsOperationLogs").value(0))
                .andExpect(jsonPath("$.data.log.operationsReviewLogs").value(0))
                .andExpect(jsonPath("$.data.log.logTotal").value(0))
                .andExpect(jsonPath("$.data.review.reviewedTotal").value(0))
                .andExpect(jsonPath("$.data.review.pendingArchiveReviews").doesNotExist())
                .andExpect(jsonPath("$.data.review.pendingOperationsReviews").value(0));

        String managerToken = login("manager", "password");
        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive").doesNotExist())
                .andExpect(jsonPath("$.data.operations").doesNotExist())
                .andExpect(jsonPath("$.data.review.reviewedTotal").value(0))
                .andExpect(jsonPath("$.data.review.pendingArchiveReviews").value(1))
                .andExpect(jsonPath("$.data.review.pendingOperationsReviews").value(0))
                .andExpect(jsonPath("$.data.log.archiveOperationLogs").value(1))
                .andExpect(jsonPath("$.data.log.archiveReviewLogs").value(0))
                .andExpect(jsonPath("$.data.log.operationsOperationLogs").value(0))
                .andExpect(jsonPath("$.data.log.operationsReviewLogs").value(0))
                .andExpect(jsonPath("$.data.log.logTotal").value(1));

        String archiveAdminToken = login("archiveadmin", "password");
        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + archiveAdminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.deviceTotal").value(3))
                .andExpect(jsonPath("$.data.operations").doesNotExist())
                .andExpect(jsonPath("$.data.review.reviewedTotal").value(0))
                .andExpect(jsonPath("$.data.review.pendingArchiveReviews").value(1))
                .andExpect(jsonPath("$.data.review.pendingOperationsReviews").doesNotExist())
                .andExpect(jsonPath("$.data.log.archiveOperationLogs").value(1))
                .andExpect(jsonPath("$.data.log.archiveReviewLogs").value(0))
                .andExpect(jsonPath("$.data.log.operationsOperationLogs").doesNotExist())
                .andExpect(jsonPath("$.data.log.operationsReviewLogs").doesNotExist())
                .andExpect(jsonPath("$.data.log.logTotal").value(1));

        String archiveStaffToken = login("archivist", "password");
        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + archiveStaffToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.deviceTotal").value(3))
                .andExpect(jsonPath("$.data.operations").doesNotExist())
                .andExpect(jsonPath("$.data.log").doesNotExist())
                .andExpect(jsonPath("$.data.review").doesNotExist());
    }

    @Test
    void includesCompletedArchiveFlowAndCountsOperationsRecordsFromCompletedWorkflow() throws Exception {
        String archiveAdminToken = login("archiveadmin", "password");
        String adminToken = login("admin", "password");
        String operatorToken = login("operator", "password");

        mockMvc.perform(post("/api/v1/device-archive-requests")
                        .header("Authorization", "Bearer " + archiveAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type": "CREATE",
                                  "deviceCode": "RDVP-DEVICE-0099",
                                  "reason": "新增现场控制柜。",
                                  "changes": {
                                    "name": {
                                      "newValue": "现场控制柜Z-99"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isOk());

        String pendingResponse = mockMvc.perform(get("/api/v1/device-archive-requests?status=PENDING_REVIEW")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String createRequestId = objectMapper.readTree(pendingResponse)
                .path("data")
                .path("items")
                .findValues("id")
                .stream()
                .map(JsonNode::asText)
                .filter(id -> !"DCR-LOCAL-0002".equals(id))
                .findFirst()
                .orElseThrow();

        verifyPassword(adminToken, "password");
        mockMvc.perform(post("/api/v1/device-archive-requests/{requestId}/review", createRequestId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "信息完整，通过。"
                                }
                                """))
                .andExpect(status().isOk());

        String faultId = createFaultReport(operatorToken);
        String repairTaskId = acceptFaultReport(operatorToken, faultId);
        verifyPassword(operatorToken, "password");
        mockMvc.perform(post("/api/v1/repair-tasks/{repairTaskId}/repair-reports", repairTaskId)
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "REPAIRED",
                                  "repairedAt": "2026-05-29T06:30:00Z",
                                  "processDescription": "已完成维修并等待复检。",
                                  "partsUsed": "Bearing assembly x1"
                                }
                                """))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/reinspections/{faultReportId}/accept", faultId)
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "longitude": 114.1694,
                                  "latitude": 22.3193
                                }
                                """))
                .andExpect(status().isOk());
        verifyPassword(operatorToken, "password");
        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/reinspection-records", faultId)
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "PASSED",
                                  "reinspectedAt": "2026-05-29T07:00:00Z",
                                  "description": "复检通过。"
                                }
                                """))
                .andExpect(status().isOk());

        verifyPassword(operatorToken, "password");
        mockMvc.perform(post("/api/v1/devices/{deviceId}/verification-records", "device-local-0002")
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "NORMAL",
                                  "description": "例行核验通过。",
                                  "verifiedAt": "2026-06-03T08:30:00Z"
                                }
                                """))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + operatorToken))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.deviceTotal").value(4))
                .andExpect(jsonPath("$.data.archive.archiveCreates").value(1))
                .andExpect(jsonPath("$.data.archive.archiveQueries").value(1))
                .andExpect(jsonPath("$.data.operations.verifications").value(1))
                .andExpect(jsonPath("$.data.operations.faultReports").value(1))
                .andExpect(jsonPath("$.data.operations.repairs").value(1))
                .andExpect(jsonPath("$.data.operations.reinspections").value(1))
                .andExpect(jsonPath("$.data.review.reviewedTotal").value(1))
                .andExpect(jsonPath("$.data.log.archiveOperationLogs").value(3))
                .andExpect(jsonPath("$.data.log.archiveReviewLogs").value(1))
                .andExpect(jsonPath("$.data.log.operationsOperationLogs").value(6))
                .andExpect(jsonPath("$.data.log.operationsReviewLogs").value(0))
                .andExpect(jsonPath("$.data.log.logTotal").value(10));
    }

    @Test
    void countsPendingAndReviewedOperationsReviews() throws Exception {
        String managerToken = login("manager", "password");
        String operatorToken = login("operator", "password");

        String faultId = createFaultReport(operatorToken);
        String repairTaskId = acceptFaultReport(operatorToken, faultId);
        verifyPassword(operatorToken, "password");
        mockMvc.perform(post("/api/v1/repair-tasks/{repairTaskId}/repair-reports", repairTaskId)
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "REPAIRED",
                                  "repairedAt": "2026-05-29T06:30:00Z",
                                  "processDescription": "已完成维修。",
                                  "partsUsed": ""
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.review.reviewedTotal").value(0))
                .andExpect(jsonPath("$.data.review.pendingOperationsReviews").value(2));

        String pendingResponse = mockMvc.perform(get("/api/v1/operations-review-requests?status=PENDING_REVIEW")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String requestId = objectMapper.readTree(pendingResponse).path("data").path("items").get(0).path("id").asText();

        verifyPassword(managerToken, "password");
        mockMvc.perform(post("/api/v1/operations-review-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + managerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "通过。"
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.review.reviewedTotal").value(1))
                .andExpect(jsonPath("$.data.review.pendingOperationsReviews").value(1));
    }

    @Test
    void countsArchiveMutationsOnlyAfterApproval() throws Exception {
        String archiveAdminToken = login("archiveadmin", "password");
        String adminToken = login("admin", "password");

        String createResponse = mockMvc.perform(post("/api/v1/device-archive-requests")
                        .header("Authorization", "Bearer " + archiveAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type": "CREATE",
                                  "deviceCode": "RDVP-DEVICE-0101",
                                  "reason": "新增测试设备。",
                                  "changes": {
                                    "name": {
                                      "newValue": "测试设备0101"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String createRequestId = objectMapper.readTree(createResponse).path("data").path("id").asText();

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.archiveCreates").value(0))
                .andExpect(jsonPath("$.data.archive.archiveUpdates").value(0))
                .andExpect(jsonPath("$.data.archive.archiveDeletes").value(0))
                .andExpect(jsonPath("$.data.review.reviewedTotal").value(0));

        verifyPassword(adminToken, "password");
        mockMvc.perform(post("/api/v1/device-archive-requests/{requestId}/review", createRequestId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "通过。"
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.archiveCreates").value(1))
                .andExpect(jsonPath("$.data.archive.archiveUpdates").value(0))
                .andExpect(jsonPath("$.data.archive.archiveDeletes").value(0))
                .andExpect(jsonPath("$.data.review.reviewedTotal").value(1));

        String updateResponse = mockMvc.perform(post("/api/v1/device-archive-requests")
                        .header("Authorization", "Bearer " + archiveAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type": "UPDATE",
                                  "deviceId": "device-local-0001",
                                  "reason": "修正部署位置。",
                                  "changes": {
                                    "location.address": {
                                      "oldValue": "一号厂房动力区",
                                      "newValue": "一号厂房动力区A段"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String updateRequestId = objectMapper.readTree(updateResponse).path("data").path("id").asText();

        String createdDeviceResponse = mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0101")
                        .header("Authorization", "Bearer " + archiveAdminToken))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String createdDeviceId = objectMapper.readTree(createdDeviceResponse).path("data").path("id").asText();

        verifyPassword(archiveAdminToken, "password");
        String deleteResponse = mockMvc.perform(post("/api/v1/device-archive-requests")
                        .header("Authorization", "Bearer " + archiveAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type": "DELETE",
                                  "deviceId": "%s",
                                  "reason": "测试退役。"
                                }
                                """.formatted(createdDeviceId)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String deleteRequestId = objectMapper.readTree(deleteResponse).path("data").path("id").asText();

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.archiveCreates").value(1))
                .andExpect(jsonPath("$.data.archive.archiveUpdates").value(0))
                .andExpect(jsonPath("$.data.archive.archiveDeletes").value(0))
                .andExpect(jsonPath("$.data.review.reviewedTotal").value(1));

        verifyPassword(adminToken, "password");
        mockMvc.perform(post("/api/v1/device-archive-requests/{requestId}/review", updateRequestId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:05:00Z",
                                  "reviewComment": "通过。"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("APPROVED"));

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.archiveCreates").value(1))
                .andExpect(jsonPath("$.data.archive.archiveUpdates").value(1))
                .andExpect(jsonPath("$.data.archive.archiveDeletes").value(0))
                .andExpect(jsonPath("$.data.review.reviewedTotal").value(2));

        verifyPassword(adminToken, "password");
        mockMvc.perform(post("/api/v1/device-archive-requests/{requestId}/review", deleteRequestId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T14:10:00Z",
                                  "reviewComment": "通过。"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("APPROVED"));

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.archiveCreates").value(1))
                .andExpect(jsonPath("$.data.archive.archiveUpdates").value(1))
                .andExpect(jsonPath("$.data.archive.archiveDeletes").value(1))
                .andExpect(jsonPath("$.data.review.reviewedTotal").value(3));
    }

    @Test
    void incrementsArchiveQueryCountOnlyForUserFacingArchiveQueries() throws Exception {
        String token = login("admin", "password");

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.archiveQueries").value(0));

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.archiveQueries").value(1));

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.archiveQueries").value(1));

        mockMvc.perform(post("/api/v1/device-qrcodes/verify")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "qrContent": "%s"
                                }
                                """.formatted(VALID_QR_CONTENT)))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.archiveQueries").value(2));
    }

    @Test
    void countsArchiveExportsAfterSuccessfulExportAndConsumesPasswordVerification() throws Exception {
        String token = login("archiveadmin", "password");

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.archiveExports").value(0));

        verifyPassword(token, "password");
        mockMvc.perform(post("/api/v1/devices/{deviceId}/archive-export-verification", "device-local-0001")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.verified").value(true));

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archive.archiveExports").value(1));

        mockMvc.perform(post("/api/v1/devices/{deviceId}/archive-export-verification", "device-local-0001")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("SENSITIVE_OPERATION_VERIFICATION_REQUIRED"));
    }

    @Test
    void protectsDashboardEndpoint() throws Exception {
        mockMvc.perform(get("/api/v1/dashboard"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
    }

    private String createFaultReport(String token) throws Exception {
        String response = mockMvc.perform(post("/api/v1/fault-reports")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceCode": "RDVP-DEVICE-0001",
                                  "faultType": "HARDWARE_DAMAGE",
                                  "severity": "SEVERE",
                                  "occurredAt": "2026-05-29T04:00:00Z",
                                  "description": "Primary bearing assembly is unstable.",
                                  "sceneCondition": "Site has reduced load."
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);

        return objectMapper.readTree(response).path("data").path("id").asText();
    }

    private String acceptFaultReport(String token, String faultId) throws Exception {
        String response = mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/accept", faultId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "longitude": 114.1694,
                                  "latitude": 22.3193
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);

        return objectMapper.readTree(response).path("data").path("repairTaskId").asText();
    }

    private void verifyPassword(String token, String password) throws Exception {
        mockMvc.perform(post("/api/v1/auth/password-verification")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "password": "%s"
                                }
                                """.formatted(password)))
                .andExpect(status().isOk());
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

        return objectMapper.readTree(response).path("data").path("accessToken").asText();
    }
}
