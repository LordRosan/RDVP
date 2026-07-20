package com.rmf.rdvp.archive.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.List;

import javax.imageio.ImageIO;

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
import com.rmf.rdvp.archive.ArchiveImage;
import com.rmf.rdvp.archive.ArchiveImageRepository;
import com.rmf.rdvp.archive.ArchiveUpdate;
import com.rmf.rdvp.archive.InMemoryArchiveRepository;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
class ArchiveRequestControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private InMemoryArchiveRepository archiveRepository;

    @Autowired
    private ArchiveImageRepository archiveImageRepository;

    @Test
    void createsArchiveRequestAndLocksArchiveEntry() throws Exception {
        String token = login("archivist", "password");

        String requestId = createNameChange(token, "冷却泵A-02");

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archiveRequestState.locked").value(true))
                .andExpect(jsonPath("$.data.archiveRequestState.pendingRequestId").value(requestId));
    }

    @Test
    void acceptsLocalDisplayInitiatedAtForArchiveRequest() throws Exception {
        String token = login("archivist", "password");
        verifyPassword(token, "password");

        mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0001",
                                  "reason": "名称修正。",
                                  "initiatedAt": "2026-06-15 20:42",
                                  "changes": {
                                    "name": {
                                      "oldValue": "冷却泵A-01",
                                      "newValue": "冷却泵A-02"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.status").value("PENDING_REVIEW"));
    }

    @Test
    void listsPendingArchiveRequestsForReviewer() throws Exception {
        String token = login("archiveadmin", "password");

        mockMvc.perform(get("/api/v1/archive-requests?status=PENDING_REVIEW")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].id").value("DCR-LOCAL-0002"))
                .andExpect(jsonPath("$.data.items[0].operatorName").value("档案员"))
                .andExpect(jsonPath("$.data.items[0].changes['location.address'].newValue")
                        .value("二号厂房包装区A段"));
    }

    @Test
    void approvesArchiveRequestAndAppliesArchiveUpdate() throws Exception {
        String applicantToken = login("archivist", "password");
        String reviewerToken = login("archiveadmin", "password");
        String requestId = createNameChange(applicantToken, "冷却泵A-02");

        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "Approved."
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("SENSITIVE_OPERATION_VERIFICATION_REQUIRED"));

        verifyPassword(reviewerToken, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
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
                .andExpect(jsonPath("$.data.freezeUntil").value("2026-06-01T14:00:00Z"));

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("冷却泵A-02"))
                .andExpect(jsonPath("$.data.archiveRequestState.locked").value(true))
                .andExpect(jsonPath("$.data.archiveRequestState.pendingRequestId").doesNotExist())
                .andExpect(jsonPath("$.data.archiveRequestState.freezeUntil").isString());
    }

    @Test
    void approvesArchiveProfileFieldUpdate() throws Exception {
        String applicantToken = login("archivist", "password");
        String reviewerToken = login("archiveadmin", "password");

        verifyPassword(applicantToken, "password");
        String response = mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + applicantToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0001",
                                  "reason": "补充档案基础信息。",
                                  "initiatedAt": "2026-06-15 20:42",
                                  "changes": {
                                    "deviceType": {
                                      "oldValue": "动力设备",
                                      "newValue": "通用设备"
                                    },
                                    "commissionedAt": {
                                      "oldValue": "2024-03-15",
                                      "newValue": "2024-04-01"
                                    },
                                    "managementDepartment": {
                                      "oldValue": "设备管理部",
                                      "newValue": "安全管理部"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.status").value("PENDING_REVIEW"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String requestId = objectMapper.readTree(response).path("data").path("id").asText();

        verifyPassword(reviewerToken, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "补充信息通过。"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("APPROVED"));

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deviceType").value("通用设备"))
                .andExpect(jsonPath("$.data.commissionedAt").value("2024-04-01"))
                .andExpect(jsonPath("$.data.managementDepartment").value("安全管理部"));
    }

    @Test
    void appliesArchiveImageReplacementOnlyAfterApproval() throws Exception {
        String applicantToken = login("archivist", "password");
        String reviewerToken = login("archiveadmin", "password");
        String originalImageId = firstArchiveImageId(reviewerToken, "device-local-0001");

        verifyPassword(applicantToken, "password");
        String response = mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + applicantToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0001",
                                  "reason": "更新设备图片。",
                                  "changes": {},
                                  "images": [
                                    {
                                      "contentBase64": "%s"
                                    }
                                  ]
                                }
                                """.formatted(testJpegBase64())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PENDING_REVIEW"))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String requestId = objectMapper.readTree(response).path("data").path("id").asText();

        assertThat(firstArchiveImageId(reviewerToken, "device-local-0001")).isEqualTo(originalImageId);
        String listResponse = mockMvc.perform(get("/api/v1/archive-requests?status=PENDING_REVIEW")
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[?(@.id == '%s')].images[0].thumbnailDataUri"
                                .formatted(requestId))
                        .value(hasItem(org.hamcrest.Matchers.startsWith("data:image/jpeg;base64,"))))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        JsonNode pendingItem = java.util.stream.StreamSupport.stream(
                        objectMapper.readTree(listResponse).path("data").path("items").spliterator(), false)
                .filter(item -> requestId.equals(item.path("id").asText()))
                .findFirst()
                .orElseThrow();
        String pendingImageId = pendingItem.path("images").get(0).path("id").asText();
        mockMvc.perform(get("/api/v1/archive-requests/{requestId}/images/{imageId}", requestId, pendingImageId)
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.dataUri").value(org.hamcrest.Matchers.startsWith(
                        "data:image/jpeg;base64,")));

        verifyPassword(reviewerToken, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "图片更新通过。"
                                }
                                """))
                .andExpect(status().isOk());

        assertThat(firstArchiveImageId(reviewerToken, "device-local-0001")).isNotEqualTo(originalImageId);
    }

    @Test
    void preservesExistingImageIdsWhenReorderingApprovedImages() throws Exception {
        ArchiveImage firstImage = archiveImageRepository.findByDeviceId("device-local-0001").getFirst();
        ArchiveImage secondImage = new ArchiveImage(
                "archive-image-local-0001-b",
                firstImage.deviceId(),
                1,
                firstImage.contentType(),
                firstImage.width(),
                firstImage.height(),
                firstImage.content(),
                firstImage.thumbnail());
        archiveImageRepository.replaceForDevice(
                "device-local-0001",
                List.of(firstImage, secondImage),
                "test-setup");

        String applicantToken = login("archivist", "password");
        String reviewerToken = login("archiveadmin", "password");
        verifyPassword(applicantToken, "password");
        String response = mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + applicantToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0001",
                                  "reason": "调整设备图片顺序。",
                                  "changes": {},
                                  "images": [
                                    { "id": "%s" },
                                    { "id": "%s" }
                                  ]
                                }
                                """.formatted(secondImage.id(), firstImage.id())))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String requestId = objectMapper.readTree(response).path("data").path("id").asText();

        verifyPassword(reviewerToken, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "图片顺序调整通过。"
                                }
                                """))
                .andExpect(status().isOk());

        assertThat(archiveImageRepository.findByDeviceId("device-local-0001"))
                .extracting(ArchiveImage::id)
                .containsExactly(secondImage.id(), firstImage.id());
    }

    @Test
    void rejectsArchiveRequestWithMoreThanFiveImages() throws Exception {
        String token = login("archivist", "password");
        String image = testJpegBase64();
        verifyPassword(token, "password");

        mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0001",
                                  "reason": "图片数量测试。",
                                  "changes": {},
                                  "images": [
                                    { "contentBase64": "%1$s" },
                                    { "contentBase64": "%1$s" },
                                    { "contentBase64": "%1$s" },
                                    { "contentBase64": "%1$s" },
                                    { "contentBase64": "%1$s" },
                                    { "contentBase64": "%1$s" }
                                  ]
                                }
                                """.formatted(image)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"));
    }

    @Test
    void rejectsArchiveRequestImageThatIsNotJpeg() throws Exception {
        String token = login("archivist", "password");
        verifyPassword(token, "password");

        mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0001",
                                  "reason": "图片格式测试。",
                                  "changes": {},
                                  "images": [
                                    { "contentBase64": "%s" }
                                  ]
                                }
                                """.formatted(testPngBase64())))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("ARCHIVE_REQUEST_INVALID"));
    }

    @Test
    void rejectsNullArchiveImagePayload() throws Exception {
        String token = login("archivist", "password");
        verifyPassword(token, "password");

        mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0001",
                                  "reason": "空图片测试。",
                                  "changes": {},
                                  "images": [null]
                                }
                                """))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_FAILED"));
    }

    @Test
    void distinguishesRemovingAllImagesFromLeavingImagesUnchanged() throws Exception {
        String applicantToken = login("archivist", "password");
        String reviewerToken = login("archiveadmin", "password");
        verifyPassword(applicantToken, "password");

        String response = mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + applicantToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0001",
                                  "reason": "删除全部设备图片。",
                                  "changes": {},
                                  "images": []
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String requestId = objectMapper.readTree(response).path("data").path("id").asText();

        mockMvc.perform(get("/api/v1/archive-requests?status=PENDING_REVIEW")
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[?(@.id == '%s')].imagesChanged".formatted(requestId))
                        .value(hasItem(true)))
                .andExpect(jsonPath("$.data.items[?(@.id == '%s')].images.length()".formatted(requestId))
                        .value(hasItem(0)));

        verifyPassword(reviewerToken, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "确认清空图片。"
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.images.length()").value(0));
    }

    @Test
    void rejectsApprovalWhenArchiveBaselineChangedAfterRequestCreation() throws Exception {
        String applicantToken = login("archivist", "password");
        String reviewerToken = login("archiveadmin", "password");
        String requestId = createNameChange(applicantToken, "冷却泵A-02");

        archiveRepository.applyUpdate(
                new ArchiveUpdate(
                        "device-local-0001",
                        "冷却泵A-后台修正",
                        "动力设备",
                        "CP-1000",
                        "北方设备",
                        OffsetDateTime.parse("2024-03-15T00:00:00Z").toLocalDate(),
                        "设备管理部",
                        "一号厂房动力区",
                        "usr-archive-admin",
                        OffsetDateTime.parse("2026-06-01T07:30:00Z")),
                null);

        verifyPassword(reviewerToken, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T08:00:00Z",
                                  "reviewComment": "基线已变化，应拒绝应用。"
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("CONFLICT"));

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("冷却泵A-后台修正"));
    }

    @Test
    void rejectsDeleteApprovalWhenArchiveSnapshotChangedAfterRequestCreation() throws Exception {
        String token = login("archiveadmin", "password");
        verifyPassword(token, "password");
        String requestId = createArchiveDeleteRequest(token, "device-local-0001");

        archiveRepository.applyUpdate(
                new ArchiveUpdate(
                        "device-local-0001",
                        "冷却泵A-待删修正",
                        "动力设备",
                        "CP-1000",
                        "北方设备",
                        OffsetDateTime.parse("2024-03-15T00:00:00Z").toLocalDate(),
                        "设备管理部",
                        "一号厂房动力区",
                        "usr-archive-admin",
                        OffsetDateTime.parse("2026-06-01T07:45:00Z")),
                null);

        verifyPassword(token, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "2026-06-01T10:00:00Z",
                                  "reviewComment": "删除前档案已变更，应拒绝应用。"
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("CONFLICT"));

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("冷却泵A-待删修正"));
    }

    @Test
    void rejectsRepeatedArchiveRequestReview() throws Exception {
        String applicantToken = login("archivist", "password");
        String reviewerToken = login("archiveadmin", "password");
        String requestId = createNameChange(applicantToken, "冷却泵A-02");

        verifyPassword(reviewerToken, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
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

        verifyPassword(reviewerToken, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
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
                .andExpect(jsonPath("$.error.code").value("ARCHIVE_REQUEST_ALREADY_REVIEWED"));
    }

    @Test
    void rejectedArchiveRequestFreezesDeviceForSixHoursAfterReview() throws Exception {
        String applicantToken = login("archivist", "password");
        String reviewerToken = login("archiveadmin", "password");
        String requestId = createNameChange(applicantToken, "冷却泵A-02");
        OffsetDateTime reviewedAt = activeReviewTimestamp();
        OffsetDateTime freezeUntil = reviewedAt.plusHours(6);

        verifyPassword(reviewerToken, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + reviewerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "REJECTED",
                                  "reviewedAt": "%s",
                                  "reviewComment": "信息不足，驳回后进入冷却。"
                                }
                                """.formatted(reviewedAt)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("REJECTED"))
                .andExpect(jsonPath("$.data.reviewedAt").value(reviewedAt.toString()))
                .andExpect(jsonPath("$.data.freezeUntil").value(freezeUntil.toString()));

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + reviewerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archiveRequestState.locked").value(true))
                .andExpect(jsonPath("$.data.archiveRequestState.pendingRequestId").doesNotExist())
                .andExpect(jsonPath("$.data.archiveRequestState.freezeUntil").value(freezeUntil.toString()));

        mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + applicantToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0001",
                                  "reason": "冻结期内再次修改。",
                                  "changes": {
                                    "name": {
                                      "oldValue": "冷却泵A-01",
                                      "newValue": "冷却泵A-03"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("ARCHIVE_REQUEST_FROZEN"));
    }

    @Test
    void rejectedCreateArchiveRequestFreezesTargetDeviceCodeForSixHoursAfterReview() throws Exception {
        String token = login("archiveadmin", "password");
        String requestId = createArchiveCreateRequest(token, "RDVP-DEVICE-0099");
        OffsetDateTime reviewedAt = activeReviewTimestamp();
        OffsetDateTime freezeUntil = reviewedAt.plusHours(6);

        verifyPassword(token, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "REJECTED",
                                  "reviewedAt": "%s",
                                  "reviewComment": "新增资料不足。"
                                }
                                """.formatted(reviewedAt)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("REJECTED"))
                .andExpect(jsonPath("$.data.freezeUntil").value(freezeUntil.toString()));

        verifyPassword(token, "password");
        mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type": "CREATE",
                                  "deviceCode": "RDVP-DEVICE-0099",
                                  "reason": "冻结期内重新提交新增申请。",
                                  "changes": {
                                    "name": {
                                      "newValue": "巡检网关G-99"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("ARCHIVE_REQUEST_FROZEN"));
    }

    @Test
    void requiresExplicitReviewTime() throws Exception {
        String applicantToken = login("archivist", "password");
        String reviewerToken = login("archiveadmin", "password");
        String requestId = createNameChange(applicantToken, "冷却泵A-02");

        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
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
        String applicantToken = login("archivist", "password");
        String reviewerToken = login("archiveadmin", "password");
        String requestId = createNameChange(applicantToken, "冷却泵A-02");

        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
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
    void createsArchiveOnlyAfterCreateRequestApproval() throws Exception {
        String token = login("archiveadmin", "password");
        String requestId = createArchiveCreateRequest(token, "RDVP-DEVICE-0099");
        OffsetDateTime reviewedAt = activeReviewTimestamp();
        OffsetDateTime freezeUntil = reviewedAt.plusHours(6);

        mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0099")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("DEVICE_NOT_FOUND"));

        verifyPassword(token, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "decision": "APPROVED",
                                  "reviewedAt": "%s",
                                  "reviewComment": "新增设备审核通过。"
                                }
                                """.formatted(reviewedAt)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("APPROVED"))
                .andExpect(jsonPath("$.data.reviewedAt").value(reviewedAt.toString()))
                .andExpect(jsonPath("$.data.freezeUntil").value(freezeUntil.toString()));

        String deviceResponse = mockMvc.perform(get("/api/v1/devices/by-code/RDVP-DEVICE-0099")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deviceCode").value("RDVP-DEVICE-0099"))
                .andExpect(jsonPath("$.data.name").value("巡检网关G-99"))
                .andExpect(jsonPath("$.data.deviceType").value("通用设备"))
                .andExpect(jsonPath("$.data.commissionedAt").value("2026-06-01"))
                .andExpect(jsonPath("$.data.managementDepartment").value("设备管理部"))
                .andExpect(jsonPath("$.data.status").value("PENDING_VERIFICATION"))
                .andExpect(jsonPath("$.data.archiveRequestState.locked").value(true))
                .andExpect(jsonPath("$.data.archiveRequestState.freezeUntil").value(freezeUntil.toString()))
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String createdDeviceId = objectMapper.readTree(deviceResponse).path("data").path("id").asText();

        verifyPassword(token, "password");
        mockMvc.perform(post("/api/v1/devices/{deviceId}/qrcode-export", createdDeviceId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deviceCode").value("RDVP-DEVICE-0099"))
                .andExpect(jsonPath("$.data.fileName").value("RDVP-DEVICE-0099.png"));

        verifyPassword(token, "password");
        mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type": "DELETE",
                                  "deviceId": "%s",
                                  "reason": "冻结期内删除新增档案。"
                                }
                                """.formatted(createdDeviceId)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("ARCHIVE_DELETE_BLOCKED"));
    }

    @Test
    void deletesArchiveOnlyAfterDeleteRequestApproval() throws Exception {
        String token = login("archiveadmin", "password");
        String imageId = firstArchiveImageId(token, "device-local-0001");
        verifyPassword(token, "password");
        String requestId = createArchiveDeleteRequest(token, "device-local-0001");

        mockMvc.perform(get("/api/v1/devices/device-local-0001")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archiveRequestState.locked").value(true))
                .andExpect(jsonPath("$.data.archiveRequestState.pendingRequestId").value(requestId));

        verifyPassword(token, "password");
        mockMvc.perform(post("/api/v1/archive-requests/{requestId}/review", requestId)
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

        mockMvc.perform(get("/api/v1/archive-images/{imageId}", imageId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    @Test
    void rejectsDeleteRequestWithoutRecentPasswordVerification() throws Exception {
        String token = login("archiveadmin", "password");

        mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type": "DELETE",
                                  "deviceId": "device-local-0001",
                                  "reason": "设备退役。"
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("SENSITIVE_OPERATION_VERIFICATION_REQUIRED"));

        String managerToken = login("manager", "password");
        mockMvc.perform(get("/api/v1/log-entries?action=ARCHIVE_REQUEST&keyword=device-local-0001")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[*].targetId").value(hasItem("device-local-0001")))
                .andExpect(jsonPath("$.data.items[*].description")
                        .value(hasItem("档案删除申请提交失败：SENSITIVE_OPERATION_VERIFICATION_REQUIRED。")));
    }

    @Test
    void rejectsCreateAndUpdateRequestsWithoutRecentPasswordVerification() throws Exception {
        String token = login("archiveadmin", "password");

        mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type": "CREATE",
                                  "deviceCode": "RDVP-DEVICE-0099",
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
                                    "deviceType": {
                                      "newValue": "通用设备"
                                    },
                                    "commissionedAt": {
                                      "newValue": "2026-06-01"
                                    },
                                    "managementDepartment": {
                                      "newValue": "设备管理部"
                                    },
                                    "location.address": {
                                      "newValue": "九号厂房巡检区"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("SENSITIVE_OPERATION_VERIFICATION_REQUIRED"));

        mockMvc.perform(post("/api/v1/archive-requests")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-local-0001",
                                  "reason": "名称修正。",
                                  "changes": {
                                    "name": {
                                      "oldValue": "冷却泵A-01",
                                      "newValue": "冷却泵A-02"
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("SENSITIVE_OPERATION_VERIFICATION_REQUIRED"));

        String managerToken = login("manager", "password");
        mockMvc.perform(get("/api/v1/log-entries?action=ARCHIVE_REQUEST&keyword=RDVP-DEVICE-0099")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[*].description")
                        .value(hasItem("档案新增申请提交失败：SENSITIVE_OPERATION_VERIFICATION_REQUIRED。")));

        mockMvc.perform(get("/api/v1/log-entries?action=ARCHIVE_REQUEST&keyword=device-local-0001")
                        .header("Authorization", "Bearer " + managerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[*].status").value(hasItem("FAILED")))
                .andExpect(jsonPath("$.data.items[*].description")
                        .value(hasItem("档案修改申请提交失败：SENSITIVE_OPERATION_VERIFICATION_REQUIRED。")));
    }

    @Test
    void rejectsDuplicatePendingArchiveRequest() throws Exception {
        String token = login("archivist", "password");
        verifyPassword(token, "password");

        mockMvc.perform(post("/api/v1/archive-requests")
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
                .andExpect(jsonPath("$.error.code").value("ARCHIVE_REQUEST_LOCKED"));
    }

    @Test
    void rejectsFrozenArchiveRequest() throws Exception {
        String token = login("archivist", "password");
        verifyPassword(token, "password");

        mockMvc.perform(post("/api/v1/archive-requests")
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
                .andExpect(jsonPath("$.error.code").value("ARCHIVE_REQUEST_FROZEN"));
    }

    @Test
    void rejectsStaleArchiveBaseline() throws Exception {
        String token = login("archivist", "password");
        verifyPassword(token, "password");

        mockMvc.perform(post("/api/v1/archive-requests")
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
    void requiresReviewPermissionForArchiveReviewEndpoints() throws Exception {
        String token = login("operator", "password");

        mockMvc.perform(get("/api/v1/archive-requests?status=PENDING_REVIEW")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
    }

    private String createNameChange(String token, String newName) throws Exception {
        verifyPassword(token, "password");
        String response = mockMvc.perform(post("/api/v1/archive-requests")
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

    private String firstArchiveImageId(String token, String deviceId) throws Exception {
        String response = mockMvc.perform(get("/api/v1/devices/{deviceId}", deviceId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        return objectMapper.readTree(response).path("data").path("images").get(0).path("id").asText();
    }

    private String testJpegBase64() throws Exception {
        BufferedImage image = new BufferedImage(8, 8, BufferedImage.TYPE_INT_RGB);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        ImageIO.write(image, "jpeg", output);
        return Base64.getEncoder().encodeToString(output.toByteArray());
    }

    private String testPngBase64() throws Exception {
        BufferedImage image = new BufferedImage(8, 8, BufferedImage.TYPE_INT_RGB);
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        ImageIO.write(image, "png", output);
        return Base64.getEncoder().encodeToString(output.toByteArray());
    }

    private static OffsetDateTime activeReviewTimestamp() {
        return OffsetDateTime.now(ZoneOffset.UTC).withNano(0);
    }

    private String createArchiveCreateRequest(String token, String deviceCode) throws Exception {
        verifyPassword(token, "password");
        String response = mockMvc.perform(post("/api/v1/archive-requests")
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
                                    "deviceType": {
                                      "newValue": "通用设备"
                                    },
                                    "commissionedAt": {
                                      "newValue": "2026-06-01"
                                    },
                                    "managementDepartment": {
                                      "newValue": "设备管理部"
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
        verifyPassword(token, "password");
        String response = mockMvc.perform(post("/api/v1/archive-requests")
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

    private void verifyPassword(String token, String password) throws Exception {
        mockMvc.perform(post("/api/v1/auth/password-verification")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "password": "%s"
                                }
                                """.formatted(password)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.verified").value(true));
    }
}
