package com.rmf.rdvp.api.workbench;

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
class WorkbenchControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void returnsSummaryForAuthenticatedUser() throws Exception {
        String operatorToken = login("fieldoperator", "password");
        String maintainerToken = login("maintainer", "password");

        createFaultReport(operatorToken, "RDVP-DEVICE-0001", "ENERGY_FAULT", "GENERAL");

        mockMvc.perform(get("/api/v1/workbench/summary")
                        .header("Authorization", "Bearer " + maintainerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.pendingChangeRequests").value(0))
                .andExpect(jsonPath("$.data.availableRepairTasks").value(1))
                .andExpect(jsonPath("$.data.activeRepairTasks").value(0))
                .andExpect(jsonPath("$.data.pendingReinspections").value(0));
    }

    @Test
    void returnsOnlyPermittedSummaryCounters() throws Exception {
        String operatorToken = login("fieldoperator", "password");
        String readonlyToken = login("readonly", "password");
        String deviceAdminToken = login("deviceadmin", "password");
        String reinspectorToken = login("reinspector", "password");

        createFaultReport(operatorToken, "RDVP-DEVICE-0001", "ENERGY_FAULT", "GENERAL");

        mockMvc.perform(get("/api/v1/workbench/summary")
                        .header("Authorization", "Bearer " + readonlyToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.pendingChangeRequests").value(0))
                .andExpect(jsonPath("$.data.availableRepairTasks").value(0))
                .andExpect(jsonPath("$.data.activeRepairTasks").value(0))
                .andExpect(jsonPath("$.data.pendingReinspections").value(0));

        mockMvc.perform(get("/api/v1/workbench/summary")
                        .header("Authorization", "Bearer " + deviceAdminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.pendingChangeRequests").value(1))
                .andExpect(jsonPath("$.data.availableRepairTasks").value(0))
                .andExpect(jsonPath("$.data.activeRepairTasks").value(0))
                .andExpect(jsonPath("$.data.pendingReinspections").value(0));

        mockMvc.perform(get("/api/v1/workbench/summary")
                        .header("Authorization", "Bearer " + reinspectorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.pendingChangeRequests").value(0))
                .andExpect(jsonPath("$.data.availableRepairTasks").value(0))
                .andExpect(jsonPath("$.data.activeRepairTasks").value(0))
                .andExpect(jsonPath("$.data.pendingReinspections").value(0));
    }

    @Test
    void requiresAuthenticationForSummary() throws Exception {
        mockMvc.perform(get("/api/v1/workbench/summary"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
    }

    private void createFaultReport(String token, String deviceCode, String faultType, String severity) throws Exception {
        mockMvc.perform(post("/api/v1/fault-reports")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceCode": "%s",
                                  "faultType": "%s",
                                  "severity": "%s",
                                  "occurredAt": "2026-05-29T04:00:00Z",
                                  "description": "Workbench summary count fixture.",
                                  "sceneCondition": "Site has reduced load."
                                }
                                """.formatted(deviceCode, faultType, severity)))
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
