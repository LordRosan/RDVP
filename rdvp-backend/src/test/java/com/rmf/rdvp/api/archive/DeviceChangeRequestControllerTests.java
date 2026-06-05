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

        String requestId = createNameChange(token, "冷却泵A-02");

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
                        .value("二号厂房包装区A段"));
    }

    @Test
    void approvesChangeRequestAndAppliesArchiveUpdate() throws Exception {
        String applicantToken = login("fieldoperator", "password");
        String reviewerToken = login("deviceadmin", "password");
        String requestId = createNameChange(applicantToken, "冷却泵A-02");

        mockMvc.perform(post("/api/v1/device-change-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "Approved."
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(requestId))
                .andExpect(jsonPath("$.data.status").value("APPROVED"))
                .andExpect(jsonPath("$.data.reviewedAt").value("2026-06-01T08:00:00Z"))
                .andExpect(jsonPath("$.data.freezeUntil").value("2026-06-01T20:00:00Z"));

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("冷却泵A-02"))
                .andExpect(jsonPath("$.data.changeState.locked").value(true))
                .andExpect(jsonPath("$.data.changeState.pendingRequestId").doesNotExist())
                .andExpect(jsonPath("$.data.changeState.freezeUntil").isString());
    }

    @Test
    void rejectsRepeatedChangeRequestReview() throws Exception {
        String applicantToken = login("fieldoperator", "password");
        String reviewerToken = login("deviceadmin", "password");
        String requestId = createNameChange(applicantToken, "冷却泵A-02");

        mockMvc.perform(post("/api/v1/device-change-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "Approved."
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/device-change-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "REJECTED",
                                  "reviewedAt": "2026-06-01T08:05:00Z",
                                  "reviewComment": "Repeated review must be rejected."
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("CHANGE_REQUEST_ALREADY_REVIEWED"));
    }

    @Test
    void requiresExplicitReviewTime() throws Exception {
        String applicantToken = login("fieldoperator", "password");
        String reviewerToken = login("deviceadmin", "password");
        String requestId = createNameChange(applicantToken, "冷却泵A-02");

        mockMvc.perform(post("/api/v1/device-change-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewComment": "Review time must be selected by the reviewer."
                                }
                                """))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"));
    }

    @Test
    void rejectsInvalidReviewDecisionWithoutUnhandledException() throws Exception {
        String applicantToken = login("fieldoperator", "password");
        String reviewerToken = login("deviceadmin", "password");
        String requestId = createNameChange(applicantToken, "冷却泵A-02");

        mockMvc.perform(post("/api/v1/device-change-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "ACCEPTED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "Unsupported decision must be rejected."
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("BAD_REQUEST"));
    }

    @Test
    void createsDeviceArchiveOnlyAfterCreateRequestApproval() throws Exception {
        String token = login("deviceadmin", "password");
        String requestId = createArchiveCreateRequest(token, "RDVP-DEVICE-0099");

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0099")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("DEVICE_NOT_FOUND"));

        mockMvc.perform(post("/api/v1/device-change-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T09:00:00Z",
                                  "reviewComment": "新增设备审核通过。"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("APPROVED"))
                .andExpect(jsonPath("$.data.reviewedAt").value("2026-06-01T09:00:00Z"));

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0099")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deviceCode").value("RDVP-DEVICE-0099"))
                .andExpect(jsonPath("$.data.name").value("巡检网关G-99"))
                .andExpect(jsonPath("$.data.status").value("PENDING_VERIFICATION"));
    }

    @Test
    void deletesDeviceArchiveOnlyAfterDeleteRequestApproval() throws Exception {
        String token = login("deviceadmin", "password");
        String requestId = createArchiveDeleteRequest(token, "device-local-0001");

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.changeState.locked").value(true))
                .andExpect(jsonPath("$.data.changeState.pendingRequestId").value(requestId));

        mockMvc.perform(post("/api/v1/device-change-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T10:00:00Z",
                                  "reviewComment": "设备退役。"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("APPROVED"));

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("DEVICE_NOT_FOUND"));
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
                                  "reason": "名称修正。",
                                  "changes": {
                                    "name": {
                                      "oldValue": "储能柜C-03",
                                      "newValue": "储能柜C-04"
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
                                  "reason": "名称修正。",
                                  "changes": {
                                    "name": {
                                      "oldValue": "Wrong Name",
                                      "newValue": "冷却泵A-02"
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
                                  "reason": "名称修正。",
                                  "changes": {
                                    "name": {
                                      "oldValue": "冷却泵A-01",
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

    private String createArchiveCreateRequest(String token, String deviceCode) throws Exception {
        String response = mockMvc.perform(post("/api/v1/device-change-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type": "CREATE",
                                  "deviceCode": "%s",
                                  "reason": "新增设备安装。",
                                  "changes": {
                                    "name": {
                                      "newValue": "巡检网关G-99"
                                    },
                                    "model": {
                                      "newValue": "IG-900"
                                    },
                                    "manufacturer": {
                                      "newValue": "北方设备"
                                    },
                                    "location.address": {
                                      "newValue": "九号厂房巡检区"
                                    }
                                  }
                                }
                                """.formatted(deviceCode)))
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

    private String createArchiveDeleteRequest(String token, String deviceId) throws Exception {
        String response = mockMvc.perform(post("/api/v1/device-change-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type": "DELETE",
                                  "deviceId": "%s",
                                  "reason": "设备退役。"
                                }
                                """.formatted(deviceId)))
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
