package com.rmf.rdvp.api.audit;

import static org.hamcrest.Matchers.hasItem;
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
class AuditLogControllerTests {

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

    @Test
    void listsAuditLogsForAuthorizedAuditor() throws Exception {
        String operatorToken = login("operator", "password");
        createFaultReport(operatorToken);
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/audit-logs?action=FAULT_REPORT")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].action").value("FAULT_REPORT"))
                .andExpect(jsonPath("$.data.items[0].targetNo").isString())
                .andExpect(jsonPath("$.data.items[0].actorName").value("运维员"))
                .andExpect(jsonPath("$.data.items[0].status").value("SUCCESS"))
                .andExpect(jsonPath("$.data.items[0].occurredAt").isString());
    }

    @Test
    void protectsAuditLogsByPermission() throws Exception {
        String archivistToken = login("archivist", "password");

        mockMvc.perform(get("/api/v1/audit-logs")
                        .header("Authorization", "Bearer " + archivistToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));

        String managerToken = login("manager", "password");
        mockMvc.perform(get("/api/v1/audit-logs?action=AUTHORIZATION_DENIED")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.data.items[0].targetNo").value("GET /api/v1/audit-logs"))
                .andExpect(jsonPath("$.data.items[0].actorName").value("档案员"))
                .andExpect(jsonPath("$.data.items[0].description").value("接口访问被拒绝：权限不足。"));
    }

    @Test
    void recordsFailedLoginForAuditReview() throws Exception {
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "username": "operator",
                                  "password": "wrong",
                                  "clientDeviceId": "test-device"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/audit-logs?action=AUTH_LOGIN")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(2))
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].targetNo").value(hasItem("operator")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].description").value(hasItem("用户登录失败。")));
    }

    @Test
    void recordsAuthenticationFailuresForAuditReview() throws Exception {
        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer invalid-token-value"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/audit-logs?action=AUTHENTICATION_FAILED")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(2))
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[*].targetNo").value(hasItem("GET /api/v1/devices/by-code/RDVP-DEVICE-0001")))
                .andExpect(jsonPath("$.data.items[*].description").value(hasItem("接口认证失败：MISSING_CREDENTIALS。")))
                .andExpect(jsonPath("$.data.items[*].description").value(hasItem("接口认证失败：INVALID_OR_EXPIRED_TOKEN。")));
    }

    @Test
    void recordsFailedPasswordVerificationForAuditReview() throws Exception {
        String archiveAdminToken = login("archiveadmin", "password");

        mockMvc.perform(post("/api/v1/auth/password-verification")
                        .header("Authorization", "Bearer " + archiveAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "password": "wrong"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/audit-logs?action=AUTH_PASSWORD_VERIFY")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.data.items[0].targetNo").value("archiveadmin"))
                .andExpect(jsonPath("$.data.items[0].actorName").value("档案管理员"))
                .andExpect(jsonPath("$.data.items[0].description").value("用户密码复核失败：INVALID_CREDENTIALS。"));
    }

    @Test
    void recordsFailedStandaloneDeviceVerificationForAuditReview() throws Exception {
        String operatorToken = login("operator", "password");

        verifyPassword(operatorToken, "password");
        mockMvc.perform(post("/api/v1/devices/{deviceId}/verification-records", "device-local-0001")
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "NORMAL",
                                  "description": "Verification time should be rejected.",
                                  "remark": "",
                                  "verifiedAt": "not-a-date"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("BAD_REQUEST"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/audit-logs?action=DEVICE_VERIFICATION")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.data.items[0].targetNo").value("RDVP-DEVICE-0001"))
                .andExpect(jsonPath("$.data.items[0].actorName").value("运维员"))
                .andExpect(jsonPath("$.data.items[0].description").value("设备核验提交失败：BAD_REQUEST。"));
    }

    @Test
    void recordsFailedDeviceArchiveRequestForAuditReview() throws Exception {
        String operatorToken = login("archivist", "password");

        mockMvc.perform(post("/api/v1/device-archive-requests")
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0002",
                                  "reason": "位置修正。",
                                  "changes": {
                                    "location.address": {
                                      "oldValue": "二号厂房包装区",
                                      "newValue": "二号厂房包装区B段"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("DEVICE_ARCHIVE_REQUEST_LOCKED"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/audit-logs?action=DEVICE_ARCHIVE_REQUEST")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.data.items[0].targetNo").value("RDVP-DEVICE-0002"))
                .andExpect(jsonPath("$.data.items[0].description").value("设备档案修改申请提交失败：DEVICE_ARCHIVE_REQUEST_LOCKED。"));
    }

    @Test
    void recordsFailedDeviceArchiveReviewForAuditReview() throws Exception {
        String reviewerToken = login("archiveadmin", "password");

        verifyPassword(reviewerToken, "password");
        mockMvc.perform(post("/api/v1/device-archive-requests/{requestId}/review", "DCR-LOCAL-0002")
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "REJECTED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": ""
                                }
                                """))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.error.code").value("DEVICE_ARCHIVE_REQUEST_INVALID"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/audit-logs?action=DEVICE_ARCHIVE_REVIEW")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.data.items[0].targetNo").value("RDVP-DEVICE-0002"))
                .andExpect(jsonPath("$.data.items[0].description").value("设备档案审核提交失败：DEVICE_ARCHIVE_REQUEST_INVALID。"));
    }

    @Test
    void recordsFailedRepairTaskAcceptForAuditReview() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");
        String faultId = createFaultReport(operatorToken);

        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/accept", faultId)
                        .header("Authorization", "Bearer " + operatorWorkerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.error.code").value("REPAIR_TASK_RADIUS_INVALID"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/audit-logs?action=REPAIR_TASK_ACCEPT")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.data.items[0].targetNo").isString())
                .andExpect(jsonPath("$.data.items[0].description").value("维修任务接取失败：REPAIR_TASK_RADIUS_INVALID。"));
    }

    @Test
    void recordsFailedFaultReportAndVerificationForAuditReview() throws Exception {
        String operatorToken = login("operator", "password");
        createFaultReport(operatorToken);

        mockMvc.perform(post("/api/v1/fault-reports")
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceCode": "RDVP-DEVICE-0001",
                                  "faultType": "COMMUNICATION_FAULT",
                                  "severity": "GENERAL",
                                  "occurredAt": "2026-05-29T04:10:00Z",
                                  "description": "Repeated report for the same active device fault.",
                                  "sceneCondition": "Duplicate submission should be rejected."
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("DEVICE_ACTIVE_FAULT_EXISTS"));

        verifyPassword(operatorToken, "password");
        mockMvc.perform(post("/api/v1/devices/{deviceId}/verification-records/fault-report", "device-local-0001")
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "ABNORMAL",
                                  "description": "设备已不可用。",
                                  "remark": "",
                                  "verifiedAt": "2026-06-03T08:30:00Z",
                                  "faultType": "ENERGY_FAULT",
                                  "severity": "SEVERE",
                                  "occurredAt": "2026-06-03T08:20:00Z",
                                  "faultDescription": "重复提交同一设备的活跃故障。",
                                  "sceneCondition": "应被系统拦截。"
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("DEVICE_ACTIVE_FAULT_EXISTS"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/audit-logs?action=FAULT_REPORT")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(2))
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].targetNo").value(hasItem("RDVP-DEVICE-0001")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].description")
                        .value(hasItem("设备报修提交失败：DEVICE_ACTIVE_FAULT_EXISTS。")));

        mockMvc.perform(get("/api/v1/audit-logs?action=DEVICE_VERIFICATION")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.data.items[0].targetNo").value("RDVP-DEVICE-0001"))
                .andExpect(jsonPath("$.data.items[0].description")
                        .value("设备核验联动报修失败：DEVICE_ACTIVE_FAULT_EXISTS。"));
    }

    @Test
    void recordsFailedRepairReportAndReinspectionForAuditReview() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");
        String operatorReinspectToken = login("operator", "password");
        String generalFaultId = createFaultReport(operatorToken);
        String generalRepairTaskId = acceptFaultReport(operatorWorkerToken, generalFaultId);

        submitRepairReport(operatorWorkerToken, generalRepairTaskId);
        mockMvc.perform(post("/api/v1/repair-tasks/{repairTaskId}/repair-reports", generalRepairTaskId)
                        .header("Authorization", "Bearer " + operatorWorkerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "REPAIRED",
                                  "repairedAt": "2026-05-29T06:05:00Z",
                                  "processDescription": "Duplicate report submission.",
                                  "partsUsed": ""
                                }
                                """))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.error.code").value("REPAIR_TASK_STATUS_INVALID"));

        String severeFaultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "HARDWARE_DAMAGE",
                "SEVERE",
                "Primary bearing assembly is unstable.");
        String severeRepairTaskId = acceptFaultReport(operatorWorkerToken, severeFaultId);
        submitRepairReport(operatorWorkerToken, severeRepairTaskId);
        submitReinspectionRecord(operatorReinspectToken, severeFaultId);
        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/reinspection-records", severeFaultId)
                        .header("Authorization", "Bearer " + operatorReinspectToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "FAILED",
                                  "reinspectedAt": "2026-05-29T07:05:00Z",
                                  "description": "Repeated reinspection must be rejected."
                                }
                                """))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.error.code").value("REINSPECTION_REQUIRED"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/audit-logs?action=REPAIR_REPORT")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(3))
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].description")
                        .value(hasItem("维修报告提交失败：REPAIR_TASK_STATUS_INVALID。")));

        mockMvc.perform(get("/api/v1/audit-logs?action=REINSPECTION_RECORD")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(2))
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].description")
                        .value(hasItem("复检报告提交失败：REINSPECTION_REQUIRED。")));
    }

    @Test
    void rejectsInvalidAuditActionFilter() throws Exception {
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/audit-logs?action=UNKNOWN_ACTION")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("BAD_REQUEST"));
    }

    @Test
    void rejectsOverlongAuditKeywordFilter() throws Exception {
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/audit-logs?keyword=" + "a".repeat(129))
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("BAD_REQUEST"));
    }

    private String createFaultReport(String token) throws Exception {
        return createFaultReport(
                token,
                "RDVP-DEVICE-0001",
                "ENERGY_FAULT",
                "GENERAL",
                "Power supply fluctuates under load.");
    }

    private String createFaultReport(
            String token,
            String deviceCode,
            String faultType,
            String severity,
            String description) throws Exception {
        String response = mockMvc.perform(post("/api/v1/fault-reports")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceCode": "%s",
                                  "faultType": "%s",
                                  "severity": "%s",
                                  "occurredAt": "2026-05-29T04:00:00Z",
                                  "description": "%s",
                                  "sceneCondition": "Site has reduced load."
                                }
                                """.formatted(deviceCode, faultType, severity, description)))
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

    private void submitReinspectionRecord(String token, String faultId) throws Exception {
        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/reinspection-records", faultId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "PASSED",
                                  "reinspectedAt": "2026-05-29T07:00:00Z",
                                  "description": "Reinspection confirms stable operation."
                                }
                                """))
                .andExpect(status().isOk());
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
