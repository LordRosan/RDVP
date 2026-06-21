package com.rmf.rdvp.api.auth;

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
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void logsInAndReturnsCurrentUser() throws Exception {
        String token = login("operator", "password");

        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.username").value("operator"))
                .andExpect(jsonPath("$.data.roles[0]").value("operationsstaff"))
                .andExpect(jsonPath("$.data.permissions").isArray());
    }

    @Test
    void normalizesUsernameBeforeLogin() throws Exception {
        String token = login(" Operator ", "password");

        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value("operator"));
    }

    @Test
    void seedsIssueDefinedRoleAccountsWithExpectedPermissions() throws Exception {
        assertUserPermissions("admin", "superadmin",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_CREATE_REQUEST_SUBMIT",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_UPDATE_REQUEST_SUBMIT",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_DELETE_REQUEST_SUBMIT",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_EXPORT",
                "OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT",
                "OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT",
                "OPERATIONS_CENTER_REPAIR_TASK_ACCEPT",
                "OPERATIONS_CENTER_REPAIR_REPORT_SUBMIT",
                "OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT",
                "OPERATIONS_CENTER_REINSPECTION_REPORT_SUBMIT",
                "MANAGEMENT_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW",
                "MANAGEMENT_CENTER_OPERATIONS_REVIEW",
                "MANAGEMENT_CENTER_ARCHIVE_RECORD_QUERY",
                "MANAGEMENT_CENTER_OPERATION_RECORD_QUERY",
                "MANAGEMENT_CENTER_REVIEW_RECORD_QUERY");
        assertUserPermissions("archiveadmin", "archiveadmin",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_CREATE_REQUEST_SUBMIT",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_UPDATE_REQUEST_SUBMIT",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_DELETE_REQUEST_SUBMIT",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_EXPORT",
                "MANAGEMENT_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW",
                "MANAGEMENT_CENTER_ARCHIVE_RECORD_QUERY");
        assertUserPermissions("archivist", "archivestaff",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_CREATE_REQUEST_SUBMIT",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_UPDATE_REQUEST_SUBMIT",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_DELETE_REQUEST_SUBMIT",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_EXPORT");
        assertUserPermissions("operationsadmin", "operationsadmin",
                "OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT",
                "OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT",
                "OPERATIONS_CENTER_REPAIR_TASK_ACCEPT",
                "OPERATIONS_CENTER_REPAIR_REPORT_SUBMIT",
                "OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT",
                "OPERATIONS_CENTER_REINSPECTION_REPORT_SUBMIT",
                "MANAGEMENT_CENTER_OPERATIONS_REVIEW",
                "MANAGEMENT_CENTER_OPERATION_RECORD_QUERY");
        assertUserPermissions("operator", "operationsstaff",
                "ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY",
                "OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT",
                "OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT",
                "OPERATIONS_CENTER_REPAIR_TASK_ACCEPT",
                "OPERATIONS_CENTER_REPAIR_REPORT_SUBMIT",
                "OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT",
                "OPERATIONS_CENTER_REINSPECTION_REPORT_SUBMIT");
        assertUserPermissions("manager", "admin",
                "MANAGEMENT_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW",
                "MANAGEMENT_CENTER_OPERATIONS_REVIEW",
                "MANAGEMENT_CENTER_ARCHIVE_RECORD_QUERY",
                "MANAGEMENT_CENTER_OPERATION_RECORD_QUERY",
                "MANAGEMENT_CENTER_REVIEW_RECORD_QUERY");
    }

    @Test
    void rejectsInvalidCredentials() throws Exception {
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "username": "operator",
                                  "password": "wrong"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    void rejectsInvalidToken() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer invalid-token"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
    }

    @Test
    void logsOutAndInvalidatesToken() throws Exception {
        String token = login("operator", "password");

        mockMvc.perform(post("/api/v1/auth/logout")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.loggedOut").value(true));

        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
    }

    @Test
    void verifiesCurrentUserPasswordWithoutCreatingSession() throws Exception {
        String token = login("archiveadmin", "password");

        mockMvc.perform(post("/api/v1/auth/password-verification")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "password": "password"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.verified").value(true));

        mockMvc.perform(post("/api/v1/auth/password-verification")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "password": "wrong"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));

        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value("archiveadmin"));
    }

    @Test
    void locksPasswordVerificationAfterConsecutiveFailures() throws Exception {
        String token = login("manager", "password");

        for (int index = 0; index < 4; index++) {
            mockMvc.perform(post("/api/v1/auth/password-verification")
                            .header("Authorization", "Bearer " + token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {
                                      "password": "wrong"
                                    }
                                    """))
                    .andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
        }

        mockMvc.perform(post("/api/v1/auth/password-verification")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "password": "wrong"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));

        mockMvc.perform(post("/api/v1/auth/password-verification")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "password": "password"
                                }
                                """))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.error.code").value("PASSWORD_VERIFICATION_LOCKED"));
    }

    @Test
    void validatesLoginRequest() throws Exception {
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "username": "",
                                  "password": ""
                                }
                                """))
                .andExpect(status().isUnprocessableContent())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.error.details").isArray());
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
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.accessToken").isString())
                .andExpect(jsonPath("$.data.expiresIn").value(604800))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);

        JsonNode root = objectMapper.readTree(response);
        String token = root.path("data").path("accessToken").asText();
        assertThat(token).isNotBlank();
        return token;
    }

    private void assertUserPermissions(String username, String role, String... permissions) throws Exception {
        String token = login(username, "password");

        var result = mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.username").value(username))
                .andExpect(jsonPath("$.data.roles[0]").value(role))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);

        JsonNode actualPermissions = objectMapper.readTree(result).path("data").path("permissions");
        assertThat(actualPermissions).hasSize(permissions.length);
        assertThat(actualPermissions)
                .extracting(JsonNode::asText)
                .containsExactlyInAnyOrder(permissions);
    }
}
