package com.rmf.rdvp.log.api;

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
class LogEntryControllerTests {

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
    void listsLogEntriesForAuthorizedAuditor() throws Exception {
        String operatorToken = login("operator", "password");
        createFaultReport(operatorToken);
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/log-entries?action=FAULT_REPORT")
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
    void protectsLogEntriesByPermission() throws Exception {
        String archivistToken = login("archivist", "password");

        mockMvc.perform(get("/api/v1/log-entries")
                        .header("Authorization", "Bearer " + archivistToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));

        String managerToken = login("manager", "password");
        mockMvc.perform(get("/api/v1/log-entries?action=AUTHORIZATION_DENIED")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.data.items[0].targetNo").value("GET /api/v1/log-entries"))
                .andExpect(jsonPath("$.data.items[0].actorName").value("档案员"))
                .andExpect(jsonPath("$.data.items[0].description").value("接口访问被拒绝：权限不足。"));
    }

    @Test
    void recordsFailedLoginForLogReview() throws Exception {
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
                .andExpect(jsonPath("$.error.code").value("PASSWORD_INCORRECT"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/log-entries?action=AUTH_LOGIN")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(2))
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].targetNo").value(hasItem("operator")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].description").value(hasItem("用户登录失败。")));
    }

    @Test
    void recordsAuthenticationFailuresForLogReview() throws Exception {
        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer invalid-token-value"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/log-entries?action=AUTHENTICATION_FAILED")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(2))
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[*].targetNo").value(hasItem("GET /api/v1/devices/by-code/RDVP-DEVICE-0001")))
                .andExpect(jsonPath("$.data.items[*].description").value(hasItem("接口认证失败：MISSING_CREDENTIALS。")))
                .andExpect(jsonPath("$.data.items[*].description").value(hasItem("接口认证失败：INVALID_OR_EXPIRED_TOKEN。")));
    }

    @Test
    void recordsFailedPasswordVerificationForLogReview() throws Exception {
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
                .andExpect(jsonPath("$.error.code").value("PASSWORD_INCORRECT"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/log-entries?action=AUTH_PASSWORD_VERIFY")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.data.items[0].targetNo").value("archiveadmin"))
                .andExpect(jsonPath("$.data.items[0].actorName").value("档案管理员"))
                .andExpect(jsonPath("$.data.items[0].description").value("用户密码复核失败：PASSWORD_INCORRECT。"));
    }

    @Test
    void recordsFailedStandaloneDeviceVerificationForLogReview() throws Exception {
        String operatorToken = login("operator", "password");

        verifyPassword(operatorToken, "password");
        mockMvc.perform(post("/api/v1/devices/{deviceId}/verification-reports", "device-local-0001")
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

        mockMvc.perform(get("/api/v1/log-entries?action=DEVICE_VERIFICATION")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.data.items[0].targetNo").value("RDVP-DEVICE-0001"))
                .andExpect(jsonPath("$.data.items[0].actorName").value("运维员"))
                .andExpect(jsonPath("$.data.items[0].description").value("核验提交失败：BAD_REQUEST。"));
    }

    @Test
    void recordsFailedArchiveRequestForLogReview() throws Exception {
        String operatorToken = login("archivist", "password");

        verifyPassword(operatorToken, "password");
        mockMvc.perform(post("/api/v1/archive-requests")
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
                .andExpect(jsonPath("$.error.code").value("ARCHIVE_REQUEST_LOCKED"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/log-entries?action=ARCHIVE_REQUEST")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.data.items[0].targetNo").value("RDVP-DEVICE-0002"))
                .andExpect(jsonPath("$.data.items[0].description").value("档案修改申请提交失败：ARCHIVE_REQUEST_LOCKED。"));
    }

    @Test
    void recordsFailedArchiveReviewForLogReview() throws Exception {
        String reviewerToken = login("archiveadmin", "password");

        verifyPassword(reviewerToken, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", "DCR-LOCAL-0002")
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
                .andExpect(jsonPath("$.error.code").value("ARCHIVE_REQUEST_INVALID"));
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/log-entries?action=ARCHIVE_REVIEW")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.data.items[0].targetNo").value("RDVP-DEVICE-0002"))
                .andExpect(jsonPath("$.data.items[0].description").value("档案审核提交失败：ARCHIVE_REQUEST_INVALID。"));
    }

    @Test
    void recordsFailedRepairTaskAcceptForLogReview() throws Exception {
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

        mockMvc.perform(get("/api/v1/log-entries?action=REPAIR_TASK_ACCEPT")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].status").value("FAILED"))
                .andExpect(jsonPath("$.data.items[0].targetNo").isString())
                .andExpect(jsonPath("$.data.items[0].description").value("维修任务接取失败：REPAIR_TASK_RADIUS_INVALID。"));
    }

    @Test
    void recordsFailedFaultReportAndVerificationForLogReview() throws Exception {
        String operatorToken = login("operator", "password");
        createFaultReport(operatorToken);

        verifyPassword(operatorToken, "password");
        mockMvc.perform(post("/api/v1/devices/{deviceId}/verification-reports/fault-report", "device-local-0001")
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

        mockMvc.perform(get("/api/v1/log-entries?action=FAULT_REPORT")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(2))
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].targetNo").value(hasItem("RDVP-DEVICE-0001")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].description")
                        .value(hasItem("报修草稿提交失败：DEVICE_ACTIVE_FAULT_EXISTS。")));

        mockMvc.perform(get("/api/v1/log-entries?action=DEVICE_VERIFICATION")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(2))
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].targetNo").value(hasItem("RDVP-DEVICE-0001")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].description")
                        .value(hasItem("核验联动报修失败：DEVICE_ACTIVE_FAULT_EXISTS。")));
    }

    @Test
    void recordsFailedRepairReportAndReinspectionForLogReview() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");
        String operatorReinspectToken = login("operator", "password");
        String generalFaultId = createApprovedFaultReport(operatorToken);
        String generalRepairTaskId = acceptFaultReport(operatorWorkerToken, generalFaultId);

        submitRepairReport(operatorWorkerToken, generalRepairTaskId);
        verifyPassword(operatorWorkerToken, "password");
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
        approveFirstOperationsReviewRequest("REPAIR_REPORT", "Repair report accepted.", "2026-06-01T09:00:00Z");

        String severeFaultId = createApprovedFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "HARDWARE_DAMAGE",
                "SEVERE",
                "Primary bearing assembly is unstable.");
        String severeRepairTaskId = acceptFaultReport(operatorWorkerToken, severeFaultId);
        submitRepairReport(operatorWorkerToken, severeRepairTaskId);
        approveFirstOperationsReviewRequest("REPAIR_REPORT", "Repair report accepted.", "2026-06-01T09:05:00Z");
        acceptReinspectionTask(operatorReinspectToken, severeFaultId);
        submitReinspectionReport(operatorReinspectToken, severeFaultId);
        verifyPassword(operatorReinspectToken, "password");
        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/reinspection-reports", severeFaultId)
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

        mockMvc.perform(get("/api/v1/log-entries?action=REPAIR_REPORT")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(4))
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[?(@.description == '系统生成复检任务。')].actorName")
                        .value(hasItem("SYSTEM")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].description")
                        .value(hasItem("维修报告提交失败：REPAIR_TASK_STATUS_INVALID。")));

        mockMvc.perform(get("/api/v1/log-entries?action=REINSPECTION_REPORT")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(2))
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[?(@.status == 'FAILED')].description")
                        .value(hasItem("复检报告提交失败：REINSPECTION_REQUIRED。")));
    }

    @Test
    void rejectsInvalidLogActionFilter() throws Exception {
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/log-entries?action=UNKNOWN_ACTION")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("BAD_REQUEST"));
    }

    @Test
    void rejectsOverlongLogKeywordFilter() throws Exception {
        String managerToken = login("manager", "password");

        mockMvc.perform(get("/api/v1/log-entries?keyword=" + "a".repeat(129))
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
        verifyPassword(token, "password");
        String response = mockMvc.perform(post("/api/v1/devices/{deviceId}/verification-reports/fault-report", deviceIdForCode(deviceCode))
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "ABNORMAL",
                                  "description": "现场核验发现设备运行异常。",
                                  "remark": "已同步填写报修草稿。",
                                  "verifiedAt": "2026-06-03T08:30:00Z",
                                  "faultType": "%s",
                                  "severity": "%s",
                                  "occurredAt": "2026-06-03T08:20:00Z",
                                  "faultDescription": "%s",
                                  "sceneCondition": "Site has reduced load."
                                }
                                """.formatted(faultType, severity, description)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.faultReport.status").value("PENDING_REVIEW"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);

        return objectMapper.readTree(response).path("data").path("faultReport").path("id").asText();
    }

    private String createApprovedFaultReport(String token) throws Exception {
        return createApprovedFaultReport(
                token,
                "RDVP-DEVICE-0001",
                "ENERGY_FAULT",
                "GENERAL",
                "Power supply fluctuates under load.");
    }

    private String createApprovedFaultReport(
            String token,
            String deviceCode,
            String faultType,
            String severity,
            String description) throws Exception {
        String faultId = createFaultReport(token, deviceCode, faultType, severity, description);
        approveFirstOperationsReviewRequest("DEVICE_VERIFICATION_REPORT", "Verification report accepted.", "2026-06-01T08:00:00Z");
        approveFirstOperationsReviewRequest("FAULT_REPORT", "Fault report accepted.", "2026-06-01T08:05:00Z");
        return faultId;
    }

    private String deviceIdForCode(String deviceCode) {
        int lastDashIndex = deviceCode.lastIndexOf('-');
        return "device-local-" + deviceCode.substring(lastDashIndex + 1);
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

    private String acceptReinspectionTask(String token, String faultId) throws Exception {
        String response = mockMvc.perform(post("/api/v1/reinspections/{faultReportId}/accept", faultId)
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

    private void submitReinspectionReport(String token, String faultId) throws Exception {
        verifyPassword(token, "password");
        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/reinspection-reports", faultId)
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

    private void approveFirstOperationsReviewRequest(String type, String comment, String reviewedAt) throws Exception {
        String reviewerToken = login("operationsadmin", "password");
        String response = mockMvc.perform(get("/api/v1/operations-review-requests")
                        .queryParam("status", "PENDING_REVIEW")
                        .queryParam("type", type)
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String requestId = objectMapper.readTree(response).path("data").path("items").get(0).path("id").asText();

        verifyPassword(reviewerToken, "password");
        mockMvc.perform(post("/api/v1/operations-review-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "%s",
                                  "reviewComment": "%s"
                                }
                                """.formatted(reviewedAt, comment)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("APPROVED"));
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
