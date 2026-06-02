package com.rmf.rdvp.api.operations;

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
class OperationsControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void createsAcceptsAndReportsRepairWorkflow() throws Exception {
        String operatorToken = login("fieldoperator", "password");
        String maintainerToken = login("maintainer", "password");

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

        mockMvc.perform(get("/api/v1/repair-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + maintainerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.workload.status").value("IDLE"))
                .andExpect(jsonPath("$.data.items[0].faultReportId").value(faultId));

        String acceptResponse = mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/accept", faultId)
                        .header("Authorization", "Bearer " + maintainerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ACCEPTED"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String repairTaskId = objectMapper.readTree(acceptResponse).path("data").path("repairTaskId").asText();

        mockMvc.perform(get("/api/v1/repair-tasks/my")
                        .header("Authorization", "Bearer " + maintainerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].id").value(repairTaskId));

        mockMvc.perform(post("/api/v1/repair-tasks/{repairTaskId}/repair-reports", repairTaskId)
                        .header("Authorization", "Bearer " + maintainerToken)
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

        mockMvc.perform(get("/api/v1/repair-tasks/my")
                        .header("Authorization", "Bearer " + maintainerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(0));

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + operatorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("NORMAL"));
    }

    @Test
    void derivesMaintainerWorkloadBeforeListingOrAcceptingTasks() throws Exception {
        String operatorToken = login("fieldoperator", "password");
        String maintainerToken = login("maintainer", "password");

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
                        .header("Authorization", "Bearer " + maintainerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/repair-tasks/available?radiusKm=20")
                        .header("Authorization", "Bearer " + maintainerToken))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.error.code").value("REPAIR_TASK_RADIUS_EXCEEDS_WORKLOAD"));

        mockMvc.perform(get("/api/v1/repair-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + maintainerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.workload.status").value("LOW_LOAD"))
                .andExpect(jsonPath("$.data.workload.maxRadiusKm").value(10));

        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/accept", secondFaultId)
                        .header("Authorization", "Bearer " + maintainerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/repair-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + maintainerToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("REPAIRER_BUSY"));

        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/accept", thirdFaultId)
                        .header("Authorization", "Bearer " + maintainerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("REPAIRER_BUSY"));
    }

    @Test
    void completesSevereRepairThroughReinspection() throws Exception {
        String operatorToken = login("fieldoperator", "password");
        String maintainerToken = login("maintainer", "password");
        String reinspectorToken = login("reinspector", "password");

        String faultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "HARDWARE_DAMAGE",
                "SEVERE",
                "Primary bearing assembly is unstable.");
        String repairTaskId = acceptFaultReport(maintainerToken, faultId);

        mockMvc.perform(post("/api/v1/repair-tasks/{repairTaskId}/repair-reports", repairTaskId)
                        .header("Authorization", "Bearer " + maintainerToken)
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
                        .header("Authorization", "Bearer " + reinspectorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].faultReportId").value(faultId))
                .andExpect(jsonPath("$.data.items[0].severity").value("SEVERE"));

        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/reinspection-records", faultId)
                        .header("Authorization", "Bearer " + reinspectorToken)
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
                        .header("Authorization", "Bearer " + reinspectorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(0));

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + operatorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("NORMAL"));
    }

    @Test
    void reopensFaultWhenReinspectionFails() throws Exception {
        String operatorToken = login("fieldoperator", "password");
        String maintainerToken = login("maintainer", "password");
        String reinspectorToken = login("reinspector", "password");

        String faultId = createFaultReport(
                operatorToken,
                "RDVP-DEVICE-0001",
                "LOGIC_FAULT",
                "EMERGENCY",
                "Control loop enters unsafe repeated restart.");
        String repairTaskId = acceptFaultReport(maintainerToken, faultId);

        mockMvc.perform(post("/api/v1/repair-tasks/{repairTaskId}/repair-reports", repairTaskId)
                        .header("Authorization", "Bearer " + maintainerToken)
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
                .andExpect(jsonPath("$.data.requiresReinspection").value(true));

        mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/reinspection-records", faultId)
                        .header("Authorization", "Bearer " + reinspectorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "FAILED",
                                  "reinspectedAt": "2026-05-29T07:00:00Z",
                                  "description": "Restart risk still exists under simulated peak load."
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.result").value("FAILED"))
                .andExpect(jsonPath("$.data.nextFaultStatus").value("PENDING_ACCEPTANCE"))
                .andExpect(jsonPath("$.data.nextDeviceStatus").value("FAULTED"));

        mockMvc.perform(get("/api/v1/repair-tasks/available?radiusKm=10")
                        .header("Authorization", "Bearer " + maintainerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].faultReportId").value(faultId));
    }

    @Test
    void protectsOperationsEndpointsByPermission() throws Exception {
        String readonlyToken = login("readonly", "password");

        mockMvc.perform(post("/api/v1/fault-reports")
                        .header("Authorization", "Bearer " + readonlyToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceCode": "RDVP-DEVICE-0001",
                                  "faultType": "ENERGY_FAULT",
                                  "severity": "GENERAL",
                                  "occurredAt": "2026-05-29T04:00:00Z",
                                  "description": "Readonly user must not submit fault reports."
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

    private String acceptFaultReport(String token, String faultId) throws Exception {
        String response = mockMvc.perform(post("/api/v1/fault-reports/{faultReportId}/accept", faultId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ACCEPTED"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        return objectMapper.readTree(response).path("data").path("repairTaskId").asText();
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
