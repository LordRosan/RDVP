package com.rmf.rdvp.archive;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("!test")
public class JdbcArchiveImageRepository implements ArchiveImageRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcArchiveImageRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public List<ArchiveImage> findByDeviceId(String deviceId) {
        return jdbcTemplate.query(
                summarySelect() + " WHERE image.device_id = :deviceId AND device.deleted_at IS NULL ORDER BY image.sort_order",
                Map.of("deviceId", deviceId),
                this::mapImage);
    }

    @Override
    public Optional<ArchiveImage> findById(String imageId) {
        return jdbcTemplate.query(
                        fullSelect() + " WHERE image.id = :imageId AND device.deleted_at IS NULL",
                        Map.of("imageId", imageId),
                        this::mapImage)
                .stream()
                .findFirst();
    }

    @Override
    public void replaceForDevice(String deviceId, List<ArchiveImage> images, String operatorId) {
        Map<String, ImageCreationAudit> existingAuditById = jdbcTemplate.query(
                        "SELECT id, created_at, created_by FROM archive_device_images WHERE device_id = :deviceId",
                        Map.of("deviceId", deviceId),
                        (resultSet, rowNumber) -> new ImageCreationAudit(
                                resultSet.getString("id"),
                                resultSet.getObject("created_at", OffsetDateTime.class),
                                resultSet.getString("created_by")))
                .stream()
                .collect(Collectors.toMap(ImageCreationAudit::id, Function.identity()));
        jdbcTemplate.update(
                "DELETE FROM archive_device_images WHERE device_id = :deviceId",
                Map.of("deviceId", deviceId));
        for (ArchiveImage image : images) {
            ImageCreationAudit existingAudit = existingAuditById.get(image.id());
            OffsetDateTime createdAt = existingAudit == null
                    ? OffsetDateTime.now(ZoneOffset.UTC)
                    : existingAudit.createdAt();
            String createdBy = existingAudit == null ? operatorId : existingAudit.createdBy();
            jdbcTemplate.update(
                    """
                            INSERT INTO archive_device_images (
                                id, device_id, sort_order, content_type, width, height,
                                image_content, thumbnail_content, created_at, created_by
                            ) VALUES (
                                :id, :deviceId, :sortOrder, :contentType, :width, :height,
                                :content, :thumbnail, :createdAt, :createdBy
                            )
                            """,
                    new MapSqlParameterSource()
                            .addValue("id", image.id())
                            .addValue("deviceId", deviceId)
                            .addValue("sortOrder", image.sortOrder())
                            .addValue("contentType", image.contentType())
                            .addValue("width", image.width())
                            .addValue("height", image.height())
                            .addValue("content", image.content())
                            .addValue("thumbnail", image.thumbnail())
                            .addValue("createdAt", createdAt)
                            .addValue("createdBy", createdBy));
        }
    }

    private String summarySelect() {
        return """
                SELECT image.id, image.device_id, image.sort_order, image.content_type,
                       image.width, image.height, NULL::bytea AS image_content, image.thumbnail_content
                FROM archive_device_images image
                JOIN archive_devices device ON device.id = image.device_id
                """;
    }

    private String fullSelect() {
        return """
                SELECT image.id, image.device_id, image.sort_order, image.content_type,
                       image.width, image.height, image.image_content, image.thumbnail_content
                FROM archive_device_images image
                JOIN archive_devices device ON device.id = image.device_id
                """;
    }

    private ArchiveImage mapImage(ResultSet resultSet, int rowNumber) throws SQLException {
        return new ArchiveImage(
                resultSet.getString("id"),
                resultSet.getString("device_id"),
                resultSet.getInt("sort_order"),
                resultSet.getString("content_type"),
                resultSet.getInt("width"),
                resultSet.getInt("height"),
                resultSet.getBytes("image_content"),
                resultSet.getBytes("thumbnail_content"));
    }

    private record ImageCreationAudit(String id, OffsetDateTime createdAt, String createdBy) {
    }
}
