package com.rmf.rdvp.archive;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@ActiveProfiles("local")
@EnabledIfSystemProperty(named = "rdvp.postgres.integration", matches = "true")
@EnabledIfEnvironmentVariable(named = "RDVP_INTEGRATION_DATASOURCE_URL", matches = "jdbc:postgresql:.+")
@Transactional
class JdbcArchiveImageRepositoryIntegrationTests {

    @DynamicPropertySource
    static void configureIntegrationDatabase(DynamicPropertyRegistry registry) {
        String url = System.getenv("RDVP_INTEGRATION_DATASOURCE_URL");
        String username = environmentOrDefault("RDVP_INTEGRATION_DATASOURCE_USERNAME", "rdvp");
        String password = environmentOrDefault("RDVP_INTEGRATION_DATASOURCE_PASSWORD", "rdvp_dev_password");
        requireEmptyDedicatedIntegrationDatabase(url, username, password);
        registry.add("spring.datasource.url", () -> url);
        registry.add("spring.datasource.username", () -> username);
        registry.add("spring.datasource.password", () -> password);
        registry.add("rdvp.bootstrap-users.enabled", () -> "false");
    }

    @Autowired
    private ArchiveImageRepository imageRepository;

    @Autowired
    private ArchiveRequestImageRepository requestImageRepository;

    @Autowired
    private NamedParameterJdbcTemplate jdbcTemplate;

    @Test
    void preservesImageIdentityAndCreationAuditWhenReordering() {
        String deviceId = jdbcTemplate.queryForObject(
                """
                        SELECT image.device_id
                        FROM archive_device_images image
                        JOIN archive_devices device ON device.id = image.device_id
                        WHERE device.deleted_at IS NULL
                        ORDER BY image.device_id, image.sort_order
                        LIMIT 1
                        """,
                Map.of(),
                String.class);
        ArchiveImage first = imageRepository.findByDeviceId(deviceId).stream()
                .findFirst()
                .flatMap(summary -> imageRepository.findById(summary.id()))
                .orElseThrow();
        ArchiveImage second = new ArchiveImage(
                "archive-image-it-" + UUID.randomUUID(),
                deviceId,
                1,
                first.contentType(),
                first.width(),
                first.height(),
                first.content(),
                first.thumbnail());

        imageRepository.replaceForDevice(deviceId, List.of(first, second), "integration-setup");
        Map<String, ImageCreationAudit> auditBeforeReorder = findAudit(first.id(), second.id());

        ArchiveImage secondFirst = new ArchiveImage(
                second.id(), deviceId, 0, second.contentType(), second.width(), second.height(),
                second.content(), second.thumbnail());
        ArchiveImage firstSecond = new ArchiveImage(
                first.id(), deviceId, 1, first.contentType(), first.width(), first.height(),
                first.content(), first.thumbnail());
        imageRepository.replaceForDevice(deviceId, List.of(secondFirst, firstSecond), "integration-reviewer");

        assertThat(imageRepository.findByDeviceId(deviceId))
                .extracting(ArchiveImage::id)
                .containsExactly(second.id(), first.id());
        assertThat(findAudit(first.id(), second.id())).isEqualTo(auditBeforeReorder);
    }

    @Test
    void loadsPendingImageChangesInOneBatchAndPreservesClearAllSemantics() {
        List<DeviceState> devices = jdbcTemplate.query(
                """
                        SELECT id, status
                        FROM archive_devices device
                        WHERE deleted_at IS NULL
                          AND NOT EXISTS (
                              SELECT 1
                              FROM review_archive_requests request
                              WHERE request.device_id = device.id
                                AND request.status = 'PENDING_REVIEW'
                          )
                        ORDER BY id
                        LIMIT 1
                        """,
                Map.of(),
                (resultSet, rowNumber) -> new DeviceState(
                        resultSet.getString("id"),
                        resultSet.getString("status")));
        assertThat(devices).hasSize(1);

        String imageRequestId = "archive-request-it-" + UUID.randomUUID();
        String clearRequestId = "archive-request-it-" + UUID.randomUUID();
        insertArchiveRequest(imageRequestId, devices.get(0));
        jdbcTemplate.update(
                "UPDATE review_archive_requests SET status = 'APPROVED' WHERE id = :requestId",
                Map.of("requestId", imageRequestId));
        insertArchiveRequest(clearRequestId, devices.get(0));

        ArchiveImage sourceImage = imageRepository.findByDeviceId(devices.get(0).id()).stream()
                .findFirst()
                .flatMap(summary -> imageRepository.findById(summary.id()))
                .orElseThrow();
        ArchiveImage pendingImage = new ArchiveImage(
                "archive-image-it-" + UUID.randomUUID(),
                devices.get(0).id(),
                0,
                sourceImage.contentType(),
                sourceImage.width(),
                sourceImage.height(),
                sourceImage.content(),
                sourceImage.thumbnail());
        requestImageRepository.saveChange(imageRequestId, List.of(pendingImage));
        requestImageRepository.saveChange(clearRequestId, List.of());

        Map<String, List<ArchiveImage>> changes = requestImageRepository.findSummaryChangesByRequestIds(
                List.of(imageRequestId, clearRequestId, "archive-request-it-missing"));

        assertThat(changes).containsOnlyKeys(imageRequestId, clearRequestId);
        assertThat(changes.get(clearRequestId)).isEmpty();
        assertThat(changes.get(imageRequestId))
                .singleElement()
                .satisfies(image -> {
                    assertThat(image.id()).isEqualTo(pendingImage.id());
                    assertThat(image.content()).isNull();
                    assertThat(image.thumbnail()).isNotEmpty();
                });
    }

    private Map<String, ImageCreationAudit> findAudit(String firstImageId, String secondImageId) {
        return jdbcTemplate.query(
                        """
                                SELECT id, created_at, created_by
                                FROM archive_device_images
                                WHERE id IN (:imageIds)
                                """,
                        Map.of("imageIds", List.of(firstImageId, secondImageId)),
                        (resultSet, rowNumber) -> new ImageCreationAudit(
                                resultSet.getString("id"),
                                resultSet.getObject("created_at", OffsetDateTime.class),
                                resultSet.getString("created_by")))
                .stream()
                .collect(java.util.stream.Collectors.toMap(ImageCreationAudit::id, audit -> audit));
    }

    private void insertArchiveRequest(String requestId, DeviceState device) {
        jdbcTemplate.update(
                """
                        INSERT INTO review_archive_requests (
                            id, request_type, device_id, applicant_id, status, previous_device_status,
                            reason, changes, initiated_at, created_at, created_by, updated_at, updated_by
                        ) VALUES (
                            :id, 'UPDATE', :deviceId, 'integration-test', 'PENDING_REVIEW', :deviceStatus,
                            'Integration image test.', '{}'::jsonb, now(), now(), 'integration-test', now(),
                            'integration-test'
                        )
                        """,
                Map.of(
                        "id", requestId,
                        "deviceId", device.id(),
                        "deviceStatus", device.status()));
    }

    private static String environmentOrDefault(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isBlank() ? fallback : value;
    }

    private static void requireEmptyDedicatedIntegrationDatabase(String url, String username, String password) {
        try (Connection connection = DriverManager.getConnection(url, username, password);
                Statement statement = connection.createStatement()) {
            String databaseName;
            try (ResultSet resultSet = statement.executeQuery("SELECT current_database()")) {
                resultSet.next();
                databaseName = resultSet.getString(1);
            }
            if (!databaseName.matches("^rdvp_integration_[a-z0-9_]+$")) {
                throw new IllegalStateException(
                        "PostgreSQL integration tests require a dedicated rdvp_integration_<id> database.");
            }

            try (ResultSet resultSet = statement.executeQuery(
                    """
                            SELECT count(*)
                            FROM information_schema.tables
                            WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
                            """)) {
                resultSet.next();
                if (resultSet.getLong(1) != 0) {
                    throw new IllegalStateException("PostgreSQL integration tests require an empty database.");
                }
            }
        } catch (SQLException exception) {
            throw new IllegalStateException("Unable to validate the PostgreSQL integration database.", exception);
        }
    }

    private record ImageCreationAudit(String id, OffsetDateTime createdAt, String createdBy) {
    }

    private record DeviceState(String id, String status) {
    }
}
