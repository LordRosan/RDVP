package com.rmf.rdvp.api.archive;

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
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class DeviceArchiveControllerTests {

    private static final String VALID_QR_CONTENT_WITH_UPPERCASE_SIGNATURE =
            "RDVP:1:RDVP-DEVICE-0001:nonce-rdvp-device-0001:F36D5F8B2A520071A5955968704A6DD4017A01E6457F573527867E47813C2807";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void findsDeviceArchiveByDeviceCode() throws Exception {
        String token = login("operator", "password");

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.id").value("device-local-0001"))
                .andExpect(jsonPath("$.data.deviceCode").value("RDVP-DEVICE-0001"))
                .andExpect(jsonPath("$.data.name").value("冷却泵A-01"))
                .andExpect(jsonPath("$.data.status").value("NORMAL"))
                .andExpect(jsonPath("$.data.archiveRequestState.locked").value(false));
    }

    @Test
    void exposesPendingArchiveRequestStateForLockedDeviceArchive() throws Exception {
        String token = login("archiveadmin", "password");

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0002")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archiveRequestState.locked").value(true))
                .andExpect(jsonPath("$.data.archiveRequestState.pendingRequestId").value("DCR-LOCAL-0002"))
                .andExpect(jsonPath("$.data.archiveRequestState.freezeUntil").doesNotExist());
    }

    @Test
    void exposesFreezeStateAsLockedDeviceArchive() throws Exception {
        String token = login("archiveadmin", "password");

        mockMvc.perform(get("/api/v1/devices/device-local-0003")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archiveRequestState.locked").value(true))
                .andExpect(jsonPath("$.data.archiveRequestState.pendingRequestId").doesNotExist())
                .andExpect(jsonPath("$.data.archiveRequestState.freezeUntil").isString());
    }

    @Test
    void rejectsInvalidDeviceCode() throws Exception {
        String token = login("operator", "password");

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-ABC1")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("DEVICE_CODE_INVALID"));
    }

    @Test
    void reportsExistingDeviceCodeAsUnavailable() throws Exception {
        String token = login("archiveadmin", "password");

        mockMvc.perform(get("/api/v1/device-codes/rdvp-device-0001/availability")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.available").value(false))
                .andExpect(jsonPath("$.data.reason").value("设备编号已被现有档案使用"));
    }

    @Test
    void reportsPendingCreateRequestDeviceCodeAsUnavailable() throws Exception {
        String token = login("archiveadmin", "password");

        mockMvc.perform(post("/api/v1/device-archive-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type": "CREATE",
                                  "deviceCode": "RDVP-DEVICE-0098",
                                  "reason": "新增设备安装。",
                                  "changes": {
                                    "name": {
                                      "newValue": "巡检网关G-98"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/device-codes/RDVP-DEVICE-0098/availability")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.available").value(false))
                .andExpect(jsonPath("$.data.reason").value("设备编号已有待审核的添加申请"));
    }

    @Test
    void reportsUnusedDeviceCodeAsAvailable() throws Exception {
        String token = login("archiveadmin", "password");

        mockMvc.perform(get("/api/v1/device-codes/RDVP-DEVICE-0097/availability")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.available").value(true))
                .andExpect(jsonPath("$.data.reason").value("设备编号可用于添加档案"));
    }

    @Test
    void rejectsInvalidDeviceId() throws Exception {
        String token = login("operator", "password");

        mockMvc.perform(get("/api/v1/devices/bad$id")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("BAD_REQUEST"));
    }

    @Test
    void verifiesQrCodeAndReturnsDeviceArchive() throws Exception {
        String token = login("operator", "password");

        mockMvc.perform(post("/api/v1/device-qrcodes/verify")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "qrContent": "%s"
                                }
                                """.formatted(VALID_QR_CONTENT_WITH_UPPERCASE_SIGNATURE)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.valid").value(true))
                .andExpect(jsonPath("$.data.device.id").value("device-local-0001"))
                .andExpect(jsonPath("$.data.device.deviceCode").value("RDVP-DEVICE-0001"));
    }

    @Test
    void rejectsTamperedQrCodeSignature() throws Exception {
        String token = login("operator", "password");

        mockMvc.perform(post("/api/v1/device-qrcodes/verify")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "qrContent": "RDVP:1:RDVP-DEVICE-0001:nonce-rdvp-device-0001:0000000000000000000000000000000000000000000000000000000000000000"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("QR_CODE_SIGNATURE_INVALID"));
    }

    @Test
    void rejectsExpiredQrCode() throws Exception {
        String token = login("operator", "password");

        mockMvc.perform(post("/api/v1/device-qrcodes/verify")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "qrContent": "RDVP:1:RDVP-DEVICE-0001:expired-rdvp-device-0001:5a408b6a7d45f3cf968521e7187a4ade6518fc479f60b01ad1ba3fc4737f8d52"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("QR_CODE_EXPIRED"));
    }

    @Test
    void rejectsMalformedQrCodeNonce() throws Exception {
        String token = login("operator", "password");

        mockMvc.perform(post("/api/v1/device-qrcodes/verify")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "qrContent": "RDVP:1:RDVP-DEVICE-0001:bad nonce:f36d5f8b2a520071a5955968704a6dd4017a01e6457f573527867e47813c2807"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("QR_CODE_INVALID"));
    }

    @Test
    void exportsDeviceQrCodeAfterPasswordVerification() throws Exception {
        String token = login("archiveadmin", "password");
        verifyPassword(token, "password");

        mockMvc.perform(post("/api/v1/devices/{deviceId}/qrcode-export", "device-local-0001")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.deviceCode").value("RDVP-DEVICE-0001"))
                .andExpect(jsonPath("$.data.fileName").value("RDVP-DEVICE-0001.png"))
                .andExpect(jsonPath("$.data.qrImageBase64").isString())
                .andExpect(jsonPath("$.data.qrContentDigest").isString())
                .andExpect(jsonPath("$.data.qrContent").doesNotExist());

        String managerToken = login("manager", "password");
        mockMvc.perform(get("/api/v1/audit-logs?action=DEVICE_ARCHIVE_EXPORT&keyword=RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("SUCCESS")))
                .andExpect(jsonPath("$.data.items[*].targetNo").value(hasItem("RDVP-DEVICE-0001")))
                .andExpect(jsonPath("$.data.items[*].actorName").value(hasItem("档案管理员")));

        mockMvc.perform(get("/api/v1/audit-logs?action=DEVICE_ARCHIVE_EXPORT&keyword=RDVP-DEVICE-9999")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(0));

        mockMvc.perform(post("/api/v1/devices/{deviceId}/qrcode-export", "device-local-0001")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("SENSITIVE_OPERATION_VERIFICATION_REQUIRED"));
    }

    @Test
    void verifiesDeviceArchiveDetailExportAndRecordsAuditLog() throws Exception {
        String token = login("archiveadmin", "password");
        verifyPassword(token, "password");

        mockMvc.perform(post("/api/v1/devices/{deviceId}/archive-export-verification", "device-local-0001")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.verified").value(true))
                .andExpect(jsonPath("$.data.deviceCode").value("RDVP-DEVICE-0001"));

        String managerToken = login("manager", "password");
        mockMvc.perform(get("/api/v1/audit-logs?action=DEVICE_ARCHIVE_EXPORT&keyword=RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("SUCCESS")))
                .andExpect(jsonPath("$.data.items[*].targetNo").value(hasItem("RDVP-DEVICE-0001")))
                .andExpect(jsonPath("$.data.items[*].actorName").value(hasItem("档案管理员")));
    }

    @Test
    void rejectsDeviceArchiveDetailExportWhenPasswordIsInvalid() throws Exception {
        String token = login("archiveadmin", "password");

        mockMvc.perform(post("/api/v1/auth/password-verification")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "password": "wrong-password"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));

        String managerToken = login("manager", "password");
        mockMvc.perform(get("/api/v1/audit-logs?action=AUTH_PASSWORD_VERIFY&keyword=archiveadmin")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[*].actorName").value(hasItem("档案管理员")));
    }

    @Test
    void protectsDeviceQrCodeExportByPermission() throws Exception {
        String token = login("operator", "password");
        verifyPassword(token, "password");

        mockMvc.perform(post("/api/v1/devices/{deviceId}/qrcode-export", "device-local-0001")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
    }

    @Test
    void rejectsDeviceQrCodeExportWhenPasswordIsInvalid() throws Exception {
        String token = login("archiveadmin", "password");

        mockMvc.perform(post("/api/v1/auth/password-verification")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "password": "wrong-password"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));

        String managerToken = login("manager", "password");
        mockMvc.perform(get("/api/v1/audit-logs?action=AUTH_PASSWORD_VERIFY&keyword=archiveadmin")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[*].actorName").value(hasItem("档案管理员")));
    }

    @Test
    void locksDeviceQrCodeExportPasswordVerificationAfterConsecutiveFailures() throws Exception {
        String token = login("admin", "password");

        for (int index = 0; index < 5; index++) {
            mockMvc.perform(post("/api/v1/auth/password-verification")
                            .header("Authorization", "Bearer " + token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {
                                      "password": "wrong-password"
                                    }
                                    """))
                    .andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.success").value(false))
                    .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
        }

        mockMvc.perform(post("/api/v1/auth/password-verification")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "password": "password"
                                }
                                """))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("PASSWORD_VERIFICATION_LOCKED"));
    }

    @Test
    void createsDeviceVerificationRecordAndUpdatesArchiveTimestamp() throws Exception {
        String token = login("operator", "password");

        verifyPassword(token, "password");
        mockMvc.perform(post("/api/v1/devices/{deviceId}/verification-records", "device-local-0001")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "ABNORMAL",
                                  "description": "现场观察到运行噪声升高，需要持续跟踪。",
                                  "remark": "建议后续上报故障。",
                                  "verifiedAt": "2026-06-03T08:30:00Z"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.deviceId").value("device-local-0001"))
                .andExpect(jsonPath("$.data.result").value("ABNORMAL"))
                .andExpect(jsonPath("$.data.description").value("现场观察到运行噪声升高，需要持续跟踪。"))
                .andExpect(jsonPath("$.data.verifiedAt").value("2026-06-03T08:30:00Z"));

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.lastVerificationTime").value("2026-06-03T08:30:00Z"));
    }

    @Test
    void protectsDeviceVerificationRecordCreationByPermission() throws Exception {
        String archivistToken = login("archivist", "password");

        mockMvc.perform(post("/api/v1/devices/{deviceId}/verification-records", "device-local-0001")
                        .header("Authorization", "Bearer " + archivistToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "result": "NORMAL",
                                  "description": "Archivist must not submit verification records.",
                                  "verifiedAt": "2026-06-03T08:30:00Z"
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
    }

    @Test
    void protectsArchiveEndpoints() throws Exception {
        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0001"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
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
