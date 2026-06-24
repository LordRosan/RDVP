package com.rmf.rdvp.api.operations;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import java.util.Set;

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
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.identity.PermissionCode;
import com.rmf.rdvp.identity.RoleCode;
import com.rmf.rdvp.identity.UserStatus;
import com.rmf.rdvp.operations.OperationsService;
import com.rmf.rdvp.operations.TaskAcceptanceItem;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
class OperationsControllerTests {

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
    private OperationsService operationsService;

    @Test
    void createsAcceptsAndReportsRepairWorkflow() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");

        String faultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "ENERGY_FAULT",
                "GENERAL",
                "Power supply fluctuates under load.");

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + operatorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FAULTED"));

        mockMvc.perform(get("/api/v1/operation-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + operatorWorkerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.workload.status").value("IDLE"))
                .andExpect(jsonPath("$.data.items[0].faultReportId").value(faultId));

        String acceptResponse = mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/accept", faultId)
                        .header("Authorization", "Bearer " + operatorWorkerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(NEAR_DEVICE_LOCATION_BODY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ACCEPTED"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String repairTaskId = objectMapper.readTree(acceptResponse).path("data").path("repairTaskId").asText();

        mockMvc.perform(get("/api/v1/repair-tasks/accepted")
                        .header("Authorization", "Bearer " + operatorWorkerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].id").value(repairTaskId));

        mockMvc.perform(post("/api/v1/repair-tasks/{repairTaskId}/repair-reports", repairTaskId)
                        .header("Authorization", "Bearer " + operatorWorkerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "REPAIRED",
                                  "repairedAt": "2026-05-29T06:00:00Z",
                                  "processDescription": "Replaced unstable connector and completed load verification.",
                                  "partsUsed": "Connector x1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.result").value("REPAIRED"))
                .andExpect(jsonPath("$.data.requiresReinspection").value(false));

        mockMvc.perform(get("/api/v1/repair-tasks/accepted")
                        .header("Authorization", "Bearer " + operatorWorkerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(0));

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + operatorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("NORMAL"));
    }

    @Test
    void rejectsDuplicateActiveFaultReportForSameDevice() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");

        createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "ENERGY_FAULT",
                "GENERAL",
                "Power supply fluctuates under load.");

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

        mockMvc.perform(get("/api/v1/operation-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + operatorWorkerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].deviceCode").value("RDVP-DEVICE-0001"));
    }

    @Test
    void rejectsFaultReportWhenOnlyOneCoordinateIsProvided() throws Exception {
        String operatorToken = login("operator", "password");

        mockMvc.perform(post("/api/v1/fault-reports")
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceCode": "RDVP-DEVICE-0001",
                                  "faultType": "COMMUNICATION_FAULT",
                                  "severity": "GENERAL",
                                  "occurredAt": "2026-05-29T04:10:00Z",
                                  "description": "Communication link is unstable.",
                                  "longitude": 114.1694
                                }
                                """))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.error.code").value("FAULT_REPORT_INVALID"));
    }

    @Test
    void rejectsFaultReportWhenCoordinateIsOutOfRange() throws Exception {
        String operatorToken = login("operator", "password");

        mockMvc.perform(post("/api/v1/fault-reports")
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceCode": "RDVP-DEVICE-0001",
                                  "faultType": "COMMUNICATION_FAULT",
                                  "severity": "GENERAL",
                                  "occurredAt": "2026-05-29T04:10:00Z",
                                  "description": "Communication link is unstable.",
                                  "longitude": 181.0000,
                                  "latitude": 22.3193
                                }
                                """))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.error.code").value("FAULT_REPORT_INVALID"));
    }

    @Test
    void filtersTaskAcceptanceByProvidedLocation() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");

        String faultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "ENERGY_FAULT",
                "GENERAL",
                "Power supply fluctuates under load.");

        mockMvc.perform(get("/api/v1/operation-tasks/available?radiusKm=1&longitude=114.1694&latitude=22.3193")
                        .header("Authorization", "Bearer " + operatorWorkerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].faultReportId").value(faultId))
                .andExpect(jsonPath("$.data.items[0].distanceKm").isNumber());

        mockMvc.perform(get("/api/v1/operation-tasks/available?radiusKm=1&longitude=120.0000&latitude=30.0000")
                        .header("Authorization", "Bearer " + operatorWorkerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(0))
                .andExpect(jsonPath("$.data.items").isEmpty());
    }

    @Test
    void rejectsPartialRepairTaskLocationQuery() throws Exception {
        String operatorWorkerToken = login("operator", "password");

        mockMvc.perform(get("/api/v1/operation-tasks/available?radiusKm=1&longitude=114.1694")
                        .header("Authorization", "Bearer " + operatorWorkerToken))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.error.code").value("REPAIR_TASK_RADIUS_INVALID"));
    }

    @Test
    void requiresLocationWhenAcceptingRepairTask() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");

        String faultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "ENERGY_FAULT",
                "GENERAL",
                "Power supply fluctuates under load.");

        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/accept", faultId)
                        .header("Authorization", "Bearer " + operatorWorkerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.error.code").value("REPAIR_TASK_RADIUS_INVALID"));
    }

    @Test
    void rejectsRepairTaskAcceptWhenLocationIsOutOfWorkloadRange() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");

        String faultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "ENERGY_FAULT",
                "GENERAL",
                "Power supply fluctuates under load.");

        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/accept", faultId)
                        .header("Authorization", "Bearer " + operatorWorkerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "longitude": 120.0000,
                                  "latitude": 30.0000
                                }
                                """))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.error.code").value("REPAIR_TASK_RADIUS_EXCEEDS_WORKLOAD"));
    }

    @Test
    void createsFaultReportWhenAbnormalVerificationIsSubmitted() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");

        verifyPassword(operatorToken, "password");
        String response = mockMvc.perform(post("/api/v1/devices/{deviceId}/verification-records/fault-report", "device-local-0001")
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "ABNORMAL",
                                  "description": "现场核验发现设备运行噪声异常。",
                                  "remark": "已同步提交报修信息。",
                                  "verifiedAt": "2026-06-03T08:30:00Z",
                                  "faultType": "OPERATION_ABNORMAL",
                                  "severity": "GENERAL",
                                  "occurredAt": "2026-06-03T08:20:00Z",
                                  "faultDescription": "设备运行噪声持续升高，存在进一步恶化风险。",
                                  "sceneCondition": "现场负载已降低，等待维修人员接取。"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.verificationRecord.deviceId").value("device-local-0001"))
                .andExpect(jsonPath("$.data.verificationRecord.result").value("ABNORMAL"))
                .andExpect(jsonPath("$.data.faultReport.status").value("PENDING_ACCEPTANCE"))
                .andExpect(jsonPath("$.data.faultReport.faultReportNo").isString())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String faultId = objectMapper.readTree(response).path("data").path("faultReport").path("id").asText();

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + operatorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("FAULTED"))
                .andExpect(jsonPath("$.data.lastVerificationTime").value("2026-06-03T08:30:00Z"));

        mockMvc.perform(get("/api/v1/operation-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + operatorWorkerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].faultReportId").value(faultId));
    }

    @Test
    void rejectsVerificationFaultReportWhenOnlyOneCoordinateIsProvided() throws Exception {
        String operatorToken = login("operator", "password");

        verifyPassword(operatorToken, "password");
        mockMvc.perform(post("/api/v1/devices/{deviceId}/verification-records/fault-report", "device-local-0001")
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "ABNORMAL",
                                  "description": "现场核验发现设备通信异常。",
                                  "remark": "坐标信息不完整，应拒绝提交。",
                                  "verifiedAt": "2026-06-03T08:30:00Z",
                                  "faultType": "COMMUNICATION_FAULT",
                                  "severity": "GENERAL",
                                  "occurredAt": "2026-06-03T08:20:00Z",
                                  "faultDescription": "通信链路持续不稳定。",
                                  "sceneCondition": "现场等待进一步排查。",
                                  "longitude": 114.1694
                                }
                                """))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.error.code").value("FAULT_REPORT_INVALID"));
    }

    @Test
    void rejectsVerificationFaultReportWhenCoordinateIsOutOfRange() throws Exception {
        String operatorToken = login("operator", "password");

        verifyPassword(operatorToken, "password");
        mockMvc.perform(post("/api/v1/devices/{deviceId}/verification-records/fault-report", "device-local-0001")
                        .header("Authorization", "Bearer " + operatorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "ABNORMAL",
                                  "description": "现场核验发现设备通信异常。",
                                  "remark": "坐标越界，应拒绝提交。",
                                  "verifiedAt": "2026-06-03T08:30:00Z",
                                  "faultType": "COMMUNICATION_FAULT",
                                  "severity": "GENERAL",
                                  "occurredAt": "2026-06-03T08:20:00Z",
                                  "faultDescription": "通信链路持续不稳定。",
                                  "sceneCondition": "现场等待进一步排查。",
                                  "longitude": 114.1694,
                                  "latitude": -91.0000
                                }
                                """))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.error.code").value("FAULT_REPORT_INVALID"));
    }

    @Test
    void rejectsDuplicateFaultReportFromAbnormalVerificationForActiveDeviceFault() throws Exception {
        String operatorToken = login("operator", "password");

        createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "ENERGY_FAULT",
                "GENERAL",
                "Power supply fluctuates under load.");

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
    }

    @Test
    void derivesMaintainerWorkloadBeforeListingOrAcceptingTasks() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");

        String firstFaultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "ENERGY_FAULT",
                "GENERAL",
                "First repair workload item.");
        String secondFaultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0002",
                "HARDWARE_DAMAGE",
                "GENERAL",
                "Second repair workload item.");
        String thirdFaultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0003",
                "COMMUNICATION_FAULT",
                "GENERAL",
                "Third repair workload item.");

        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/accept", firstFaultId)
                        .header("Authorization", "Bearer " + operatorWorkerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(NEAR_DEVICE_LOCATION_BODY))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/operation-tasks/available?radiusKm=20")
                        .header("Authorization", "Bearer " + operatorWorkerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.workload.status").value("LOW_LOAD"))
                .andExpect(jsonPath("$.data.workload.maxRadiusKm").value(20));

        mockMvc.perform(get("/api/v1/operation-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + operatorWorkerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.workload.status").value("LOW_LOAD"))
                .andExpect(jsonPath("$.data.workload.maxRadiusKm").value(20));

        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/accept", secondFaultId)
                        .header("Authorization", "Bearer " + operatorWorkerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(NEAR_DEVICE_LOCATION_BODY))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/operation-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + operatorWorkerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.workload.status").value("MEDIUM_LOAD"))
                .andExpect(jsonPath("$.data.workload.maxRadiusKm").value(10));

        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/accept", thirdFaultId)
                        .header("Authorization", "Bearer " + operatorWorkerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(NEAR_DEVICE_LOCATION_BODY))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/operation-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + operatorWorkerToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("REPAIRER_BUSY"));
    }

    @Test
    void completesSevereRepairThroughReinspection() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");
        String operatorReinspectToken = login("operator", "password");

        String faultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "HARDWARE_DAMAGE",
                "SEVERE",
                "Primary bearing assembly is unstable.");
        String repairTaskId = acceptFaultReport(operatorWorkerToken, faultId);

        mockMvc.perform(post("/api/v1/repair-tasks/{repairTaskId}/repair-reports", repairTaskId)
                        .header("Authorization", "Bearer " + operatorWorkerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "REPAIRED",
                                  "repairedAt": "2026-05-29T06:30:00Z",
                                  "processDescription": "Replaced bearing assembly and completed no-load operation check.",
                                  "partsUsed": "Bearing assembly x1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requiresReinspection").value(true));

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + operatorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PENDING_REINSPECTION"));

        mockMvc.perform(get("/api/v1/reinspections/pending")
                        .header("Authorization", "Bearer " + operatorReinspectToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].faultReportId").value(faultId))
                .andExpect(jsonPath("$.data.items[0].severity").value("SEVERE"));

        mockMvc.perform(get("/api/v1/operation-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + operatorReinspectToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].faultReportId").value(faultId))
                .andExpect(jsonPath("$.data.items[0].taskType").value("REINSPECTION"));

        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/reinspection-records", faultId)
                        .header("Authorization", "Bearer " + operatorReinspectToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "PASSED",
                                  "reinspectedAt": "2026-05-29T07:00:00Z",
                                  "description": "Reinspection confirms stable operation under controlled load."
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.result").value("PASSED"))
                .andExpect(jsonPath("$.data.nextFaultStatus").value("CLOSED"))
                .andExpect(jsonPath("$.data.nextDeviceStatus").value("NORMAL"));

        mockMvc.perform(get("/api/v1/reinspections/pending")
                        .header("Authorization", "Bearer " + operatorReinspectToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(0));

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + operatorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("NORMAL"));
    }

    @Test
    void filtersUnifiedTaskAcceptanceByTaskAcceptPermission() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");

        String faultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "HARDWARE_DAMAGE",
                "SEVERE",
                "Primary bearing assembly is unstable.");
        String repairTaskId = acceptFaultReport(operatorWorkerToken, faultId);
        submitRepairReport(operatorWorkerToken, repairTaskId);

        var reinspectionOnlyUser = new AuthenticatedUser(
                "usr-reinspection-only",
                "reinspectiononly",
                "复检员",
                UserStatus.ACTIVE,
                Set.of(RoleCode.OPERATIONS_STAFF),
                Set.of(PermissionCode.OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT));
        var repairOnlyUser = new AuthenticatedUser(
                "usr-repair-only",
                "repaironly",
                "维修员",
                UserStatus.ACTIVE,
                Set.of(RoleCode.OPERATIONS_STAFF),
                Set.of(PermissionCode.OPERATIONS_CENTER_REPAIR_TASK_ACCEPT));

        var reinspectionTasks = operationsService.listTaskAcceptance(10, null, null, null, reinspectionOnlyUser);
        org.assertj.core.api.Assertions.assertThat(reinspectionTasks.items())
                .extracting(TaskAcceptanceItem::taskType)
                .containsExactly("REINSPECTION");

        var repairTasks = operationsService.listTaskAcceptance(10, null, null, null, repairOnlyUser);
        org.assertj.core.api.Assertions.assertThat(repairTasks.items()).isEmpty();
    }

    @Test
    void rejectsRepeatedRepairReportSubmission() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");

        String faultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "ENERGY_FAULT",
                "GENERAL",
                "Power supply fluctuates under load.");
        String repairTaskId = acceptFaultReport(operatorWorkerToken, faultId);

        submitRepairReport(operatorWorkerToken, repairTaskId);

        mockMvc.perform(post("/api/v1/repair-tasks/{repairTaskId}/repair-reports", repairTaskId)
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
    }

    @Test
    void createsAndReviewsPendingOperationsReviewForRepairReport() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");
        String reviewerToken = login("operationsadmin", "password");

        String faultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "ENERGY_FAULT",
                "GENERAL",
                "Power supply fluctuates under load.");
        String repairTaskId = acceptFaultReport(operatorWorkerToken, faultId);
        submitRepairReport(operatorWorkerToken, repairTaskId);

        String listResponse = mockMvc.perform(get("/api/v1/operation-review-requests?status=PENDING_REVIEW")
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].type").value("REPAIR_REPORT"))
                .andExpect(jsonPath("$.data.items[0].status").value("PENDING_REVIEW"))
                .andExpect(jsonPath("$.data.items[0].targetId").isString())
                .andExpect(jsonPath("$.data.items[0].deviceCode").value("RDVP-DEVICE-0001"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String requestId = objectMapper.readTree(listResponse).path("data").path("items").get(0).path("id").asText();

        mockMvc.perform(post("/api/v1/operation-review-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "Repair report accepted."
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(requestId))
                .andExpect(jsonPath("$.data.status").value("APPROVED"))
                .andExpect(jsonPath("$.data.reviewedAt").value("2026-06-01T08:00:00Z"));

        mockMvc.perform(get("/api/v1/operation-review-requests?status=PENDING_REVIEW")
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(0));
    }

    @Test
    void requiresOperationsReviewPermissionForManagementReviewEndpoints() throws Exception {
        String operatorToken = login("operator", "password");

        mockMvc.perform(get("/api/v1/operation-review-requests?status=PENDING_REVIEW")
                        .header("Authorization", "Bearer " + operatorToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
    }

    @Test
    void requeuesEmergencyTemporaryRepairWithoutReinspection() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");

        String faultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "LOGIC_FAULT",
                "EMERGENCY",
                "Control loop enters unsafe repeated restart.");
        String repairTaskId = acceptFaultReport(operatorWorkerToken, faultId);

        mockMvc.perform(post("/api/v1/repair-tasks/{repairTaskId}/repair-reports", repairTaskId)
                        .header("Authorization", "Bearer " + operatorWorkerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "TEMPORARY_RESTORED",
                                  "repairedAt": "2026-05-29T06:30:00Z",
                                  "processDescription": "Applied temporary rollback and isolated unstable logic branch.",
                                  "partsUsed": ""
                                }
                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.requiresReinspection").value(false));

        mockMvc.perform(get("/api/v1/operation-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + operatorWorkerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].faultReportId").value(faultId));
    }

    @Test
    void rejectsRepeatedReinspectionRecordSubmission() throws Exception {
        String operatorToken = login("operator", "password");
        String operatorWorkerToken = login("operator", "password");
        String operatorReinspectToken = login("operator", "password");

        String faultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "HARDWARE_DAMAGE",
                "SEVERE",
                "Primary bearing assembly is unstable.");
        String repairTaskId = acceptFaultReport(operatorWorkerToken, faultId);
        submitRepairReport(operatorWorkerToken, repairTaskId);

        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/reinspection-records", faultId)
                        .header("Authorization", "Bearer " + operatorReinspectToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "PASSED",
                                  "reinspectedAt": "2026-05-29T07:00:00Z",
                                  "description": "Reinspection confirms stable operation."
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/reinspection-records", faultId)
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
    }

    @Test
    void protectsOperationsEndpointsByPermission() throws Exception {
        String archivistToken = login("archivist", "password");

        mockMvc.perform(post("/api/v1/fault-reports")
                        .header("Authorization", "Bearer " + archivistToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceCode": "RDVP-DEVICE-0001",
                                  "faultType": "ENERGY_FAULT",
                                  "severity": "GENERAL",
                                  "occurredAt": "2026-05-29T04:00:00Z",
                                  "description": "Archivist must not submit fault reports."
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
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
