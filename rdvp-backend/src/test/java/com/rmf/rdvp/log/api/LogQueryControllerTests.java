package com.rmf.rdvp.log.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;

import org.junit.jupiter.api.BeforeEach;
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
import com.rmf.rdvp.user.LoginAttemptStore;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
class LogQueryControllerTests {

    private static final String NEAR_DEVICE_LOCATION_BODY = """
            {
              "longitude": 114.1694,
              "latitude": 22.3193
            }
            """;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private LoginAttemptStore loginAttemptStore;

    @BeforeEach
    void clearLoginAttempts() {
        loginAttemptStore.clear("admin");
        loginAttemptStore.clear("archiveadmin");
        loginAttemptStore.clear("operationsadmin");
        loginAttemptStore.clear("operator");
        loginAttemptStore.clear("manager");
    }

    @Test
    void gatesLogCategoriesBySplitPermissions() throws Exception {
        String archiveAdminToken = login("archiveadmin", "password");
        String operationsAdminToken = login("operationsadmin", "password");
        String managerToken = login("manager", "password");

        expectLogCategory(archiveAdminToken, "ARCHIVE_OPERATION", true);
        expectLogCategory(archiveAdminToken, "ARCHIVE_REVIEW", true);
        expectLogCategory(archiveAdminToken, "OPERATIONS_OPERATION", false);
        expectLogCategory(archiveAdminToken, "OPERATIONS_REVIEW", false);

        expectLogCategory(operationsAdminToken, "ARCHIVE_OPERATION", false);
        expectLogCategory(operationsAdminToken, "ARCHIVE_REVIEW", false);
        expectLogCategory(operationsAdminToken, "OPERATIONS_OPERATION", true);
        expectLogCategory(operationsAdminToken, "OPERATIONS_REVIEW", true);

        expectLogCategory(managerToken, "ARCHIVE_OPERATION", true);
        expectLogCategory(managerToken, "ARCHIVE_REVIEW", true);
        expectLogCategory(managerToken, "OPERATIONS_OPERATION", true);
        expectLogCategory(managerToken, "OPERATIONS_REVIEW", true);
    }

    @Test
    void reviewLogsIncludeReviewedOperationRequests() throws Exception {
        String operatorToken = login("operator", "password");
        String managerToken = login("manager", "password");

        String faultId = createFaultReport(operatorToken);
        String repairTaskId = acceptFaultReport(operatorToken, faultId);
        submitRepairReport(operatorToken, repairTaskId);
        String requestId = findPendingOperationsReviewRequest(managerToken);

        verifyPassword(managerToken, "password");
        mockMvc.perform(post("/api/v1/operations-review-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + managerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "Repair report accepted."
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("APPROVED"));

        mockMvc.perform(get("/api/v1/log-center/logs")
                        .queryParam("category", "OPERATIONS_REVIEW")
                        .queryParam("type", "REPAIR_REPORT")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].logCategory").value("OPERATIONS_REVIEW"))
                .andExpect(jsonPath("$.data.items[0].logType").value("REPAIR_REPORT"))
                .andExpect(jsonPath("$.data.items[0].deviceCode").value("RDVP-DEVICE-0001"))
                .andExpect(jsonPath("$.data.items[0].taskNo").isString())
                .andExpect(jsonPath("$.data.items[0].businessStatus").value("APPROVED"))
                .andExpect(jsonPath("$.data.items[0].description").value("Repair report accepted."));
    }

    @Test
    void reviewLogsCanBeFilteredByDateRange() throws Exception {
        String operatorToken = login("operator", "password");
        String managerToken = login("manager", "password");

        String faultId = createFaultReport(operatorToken);
        String repairTaskId = acceptFaultReport(operatorToken, faultId);
        submitRepairReport(operatorToken, repairTaskId);
        String requestId = findPendingOperationsReviewRequest(managerToken);

        verifyPassword(managerToken, "password");
        mockMvc.perform(post("/api/v1/operations-review-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + managerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "Repair report accepted."
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/log-center/logs")
                        .queryParam("category", "OPERATIONS_REVIEW")
                        .queryParam("type", "REPAIR_REPORT")
                        .queryParam("startDate", "2026-06-01")
                        .queryParam("endDate", "2026-06-01")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1));

        mockMvc.perform(get("/api/v1/log-center/logs")
                        .queryParam("category", "OPERATIONS_REVIEW")
                        .queryParam("type", "REPAIR_REPORT")
                        .queryParam("startDate", "2026-06-02")
                        .queryParam("endDate", "2026-06-02")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(0));
    }

    @Test
    void rejectsLogQueryEndDateLaterThanToday() throws Exception {
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/log-center/logs")
                        .queryParam("category", "OPERATIONS_REVIEW")
                        .queryParam("endDate", "2099-01-01")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("BAD_REQUEST"));
    }

    @Test
    void doesNotRetainLegacyLogRoutes() throws Exception {
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/operation-records")
                        .queryParam("category", "OPERATIONS")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));

        mockMvc.perform(get("/api/v1/management-records")
                        .queryParam("category", "OPERATIONS")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));

        mockMvc.perform(get("/api/v1/record-center/records")
                        .queryParam("category", "OPERATIONS")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
    }

    @Test
    void archiveLogsIncludeArchiveQueryLogEntries() throws Exception {
        String archiveAdminToken = login("archiveadmin", "password");
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/devices/by-code/{deviceCode}", "RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + archiveAdminToken))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/log-center/logs")
                        .queryParam("category", "ARCHIVE_OPERATION")
                        .queryParam("type", "DEVICE_ARCHIVE_QUERY")
                        .queryParam("keyword", "RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].logCategory").value("ARCHIVE_OPERATION"))
                .andExpect(jsonPath("$.data.items[0].logType").value("DEVICE_ARCHIVE_QUERY"))
                .andExpect(jsonPath("$.data.items[0].deviceCode").value("RDVP-DEVICE-0001"));
    }

    private void expectLogCategory(String token, String category, boolean allowed) throws Exception {
        var request = get("/api/v1/log-center/logs")
                .queryParam("category", category)
                .header("Authorization", "Bearer " + token);

        if (allowed) {
            mockMvc.perform(request)
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.success").value(true));
            return;
        }

        mockMvc.perform(request)
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
    }

    private String createFaultReport(String token) throws Exception {
        String response = mockMvc.perform(post("/api/v1/fault-reports")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceCode": "RDVP-DEVICE-0001",
                                  "faultType": "ENERGY_FAULT",
                                  "severity": "GENERAL",
                                  "occurredAt": "2026-05-29T04:00:00Z",
                                  "description": "Power supply fluctuates under load.",
                                  "sceneCondition": "Site has reduced load."
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PENDING_ACCEPTANCE"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        return objectMapper.readTree(response).path("data").path("id").asText();
    }

    private String acceptFaultReport(String token, String faultId) throws Exception {
        String response = mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/accept", faultId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(NEAR_DEVICE_LOCATION_BODY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ACCEPTED"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        return objectMapper.readTree(response).path("data").path("repairTaskId").asText();
    }

    private void submitRepairReport(String token, String repairTaskId) throws Exception {
        verifyPassword(token, "password");
        mockMvc.perform(post("/api/v1/repair-tasks/{repairTaskId}/repair-reports", repairTaskId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "REPAIRED",
                                  "repairedAt": "2026-05-29T06:00:00Z",
                                  "processDescription": "Replaced unstable connector and completed load verification.",
                                  "partsUsed": "Connector x1"
                                }
                                """))
                .andExpect(status().isOk());
    }

    private String findPendingOperationsReviewRequest(String token) throws Exception {
        String response = mockMvc.perform(get("/api/v1/operations-review-requests")
                        .queryParam("status", "PENDING_REVIEW")
                        .queryParam("type", "REPAIR_REPORT")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        return objectMapper.readTree(response).path("data").path("items").get(0).path("id").asText();
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

        JsonNode root = objectMapper.readTree(response);
        return root.path("data").path("accessToken").asText();
    }
}
