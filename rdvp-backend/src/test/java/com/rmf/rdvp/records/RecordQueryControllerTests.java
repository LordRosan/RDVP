package com.rmf.rdvp.records;

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
class RecordQueryControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void gatesRecordCategoriesBySplitPermissions() throws Exception {
        String archiveAdminToken = login("archiveadmin", "password");
        String operationsAdminToken = login("operationsadmin", "password");
        String managerToken = login("manager", "password");

        expectRecordCategory(archiveAdminToken, "ARCHIVE", true);
        expectRecordCategory(archiveAdminToken, "OPERATIONS", false);
        expectRecordCategory(archiveAdminToken, "REVIEW", false);

        expectRecordCategory(operationsAdminToken, "ARCHIVE", false);
        expectRecordCategory(operationsAdminToken, "OPERATIONS", true);
        expectRecordCategory(operationsAdminToken, "REVIEW", false);

        expectRecordCategory(managerToken, "ARCHIVE", true);
        expectRecordCategory(managerToken, "OPERATIONS", true);
        expectRecordCategory(managerToken, "REVIEW", true);
    }

    private void expectRecordCategory(String token, String category, boolean allowed) throws Exception {
        var request = get("/api/v1/operation-records")
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
