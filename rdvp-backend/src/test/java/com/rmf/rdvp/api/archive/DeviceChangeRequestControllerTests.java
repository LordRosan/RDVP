package com.rmf.rdvp.api.archive;

import static org.assertj.core.api.Assertions.assertThat;
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
class DeviceChangeRequestControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void createsChangeRequestAndLocksArchiveEntry() throws Exception {
        String token = login("fieldoperator", "password");

        String requestId = createNameChange(token, "Cooling Pump A-02");

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.changeState.locked").value(true))
                .andExpect(jsonPath("$.data.changeState.pendingRequestId").value(requestId));
    }

    @Test
    void listsPendingChangeRequestsForReviewer() throws Exception {
        String token = login("deviceadmin", "password");

        mockMvc.perform(get("/api/v1/device-change-requests?status=PENDING_REVIEW")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].id").value("DCR-LOCAL-0002"))
                .andExpect(jsonPath("$.data.items[0].applicantName").value("现场运维人员"))
                .andExpect(jsonPath("$.data.items[0].changes['location.address'].newValue")
                        .value("Plant 2 Packaging Area Section A"));
    }

    @Test
    void approvesChangeRequestAndAppliesArchiveUpdate() throws Exception {
        String applicantToken = login("fieldoperator", "password");
        String reviewerToken = login("deviceadmin", "password");
        String requestId = createNameChange(applicantToken, "Cooling Pump A-02");

        mockMvc.perform(post("/api/v1/device-change-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewComment": "Approved."
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(requestId))
                .andExpect(jsonPath("$.data.status").value("APPROVED"))
                .andExpect(jsonPath("$.data.reviewedAt").isString())
                .andExpect(jsonPath("$.data.freezeUntil").isString());

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("Cooling Pump A-02"))
                .andExpect(jsonPath("$.data.changeState.locked").value(true))
                .andExpect(jsonPath("$.data.changeState.pendingRequestId").doesNotExist())
                .andExpect(jsonPath("$.data.changeState.freezeUntil").isString());
    }

    @Test
    void rejectsDuplicatePendingChangeRequest() throws Exception {
        String token = login("fieldoperator", "password");

        mockMvc.perform(post("/api/v1/device-change-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0002",
                                  "reason": "Location correction.",
                                  "changes": {
                                    "location.address": {
                                      "oldValue": "Plant 2 Packaging Area",
                                      "newValue": "Plant 2 Packaging Area Section B"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("DEVICE_CHANGE_LOCKED"));
    }

    @Test
    void rejectsFrozenArchiveChangeRequest() throws Exception {
        String token = login("fieldoperator", "password");

        mockMvc.perform(post("/api/v1/device-change-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0003",
                                  "reason": "Name correction.",
                                  "changes": {
                                    "name": {
                                      "oldValue": "Energy Cabinet C-03",
                                      "newValue": "Energy Cabinet C-04"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("DEVICE_CHANGE_FROZEN"));
    }

    @Test
    void rejectsStaleArchiveBaseline() throws Exception {
        String token = login("fieldoperator", "password");

        mockMvc.perform(post("/api/v1/device-change-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0001",
                                  "reason": "Name correction.",
                                  "changes": {
                                    "name": {
                                      "oldValue": "Wrong Name",
                                      "newValue": "Cooling Pump A-02"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("CONFLICT"));
    }

    @Test
    void requiresReviewPermissionForManagementEndpoints() throws Exception {
        String token = login("fieldoperator", "password");

        mockMvc.perform(get("/api/v1/device-change-requests?status=PENDING_REVIEW")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
    }

    private String createNameChange(String token, String newName) throws Exception {
        String response = mockMvc.perform(post("/api/v1/device-change-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0001",
                                  "reason": "Name correction.",
                                  "changes": {
                                    "name": {
                                      "oldValue": "Cooling Pump A-01",
                                      "newValue": "%s"
                                    }
                                  }
                                }
                                """.formatted(newName)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.status").value("PENDING_REVIEW"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);

        JsonNode root = objectMapper.readTree(response);
        String requestId = root.path("data").path("id").asText();
        assertThat(requestId).startsWith("DCR-");
        return requestId;
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
