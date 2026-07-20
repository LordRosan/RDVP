package com.rmf.rdvp.archive;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("!test")
public class JdbcArchiveRequestImageRepository implements ArchiveRequestImageRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcArchiveRequestImageRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void saveChange(String requestId, List<ArchiveImage> images) {
        jdbcTemplate.update(
                "UPDATE review_archive_requests SET images_changed = true WHERE id = :requestId",
                Map.of("requestId", requestId));
        for (ArchiveImage image : images) {
            jdbcTemplate.update(
                    """
                            INSERT INTO review_archive_request_images (
                                id, request_id, sort_order, content_type, width, height,
                                image_content, thumbnail_content, created_at
                            ) VALUES (
                                :id, :requestId, :sortOrder, :contentType, :width, :height,
                                :content, :thumbnail, now()
                            )
                            """,
                    new MapSqlParameterSource()
                            .addValue("id", image.id())
                            .addValue("requestId", requestId)
                            .addValue("sortOrder", image.sortOrder())
                            .addValue("contentType", image.contentType())
                            .addValue("width", image.width())
                            .addValue("height", image.height())
                            .addValue("content", image.content())
                            .addValue("thumbnail", image.thumbnail()));
        }
    }

    @Override
    public Optional<List<ArchiveImage>> findChangeByRequestId(String requestId) {
        return findChangeByRequestId(requestId, true);
    }

    @Override
    public Map<String, List<ArchiveImage>> findSummaryChangesByRequestIds(List<String> requestIds) {
        if (requestIds.isEmpty()) {
            return Map.of();
        }
        return jdbcTemplate.query(
                """
                        SELECT request.id AS request_id,
                               image.id, image.sort_order, image.content_type, image.width, image.height,
                               image.thumbnail_content
                        FROM review_archive_requests request
                        LEFT JOIN review_archive_request_images image ON image.request_id = request.id
                        WHERE request.id IN (:requestIds)
                          AND request.images_changed = true
                        ORDER BY request.id, image.sort_order
                        """,
                Map.of("requestIds", requestIds),
                resultSet -> {
                    Map<String, List<ArchiveImage>> changesByRequestId = new LinkedHashMap<>();
                    while (resultSet.next()) {
                        String requestId = resultSet.getString("request_id");
                        List<ArchiveImage> images = changesByRequestId.computeIfAbsent(
                                requestId,
                                ignored -> new ArrayList<>());
                        String imageId = resultSet.getString("id");
                        if (imageId != null) {
                            images.add(new ArchiveImage(
                                    imageId,
                                    requestId,
                                    resultSet.getInt("sort_order"),
                                    resultSet.getString("content_type"),
                                    resultSet.getInt("width"),
                                    resultSet.getInt("height"),
                                    null,
                                    resultSet.getBytes("thumbnail_content")));
                        }
                    }
                    return changesByRequestId;
                });
    }

    @Override
    public Optional<ArchiveImage> findByRequestIdAndImageId(String requestId, String imageId) {
        return jdbcTemplate.query(
                        imageSelect(true) + " WHERE request_id = :requestId AND id = :imageId",
                        Map.of("requestId", requestId, "imageId", imageId),
                        (resultSet, rowNumber) -> new ArchiveImage(
                                resultSet.getString("id"),
                                requestId,
                                resultSet.getInt("sort_order"),
                                resultSet.getString("content_type"),
                                resultSet.getInt("width"),
                                resultSet.getInt("height"),
                                resultSet.getBytes("image_content"),
                                resultSet.getBytes("thumbnail_content")))
                .stream()
                .findFirst();
    }

    private Optional<List<ArchiveImage>> findChangeByRequestId(String requestId, boolean includeContent) {
        Boolean changed = jdbcTemplate.queryForObject(
                "SELECT images_changed FROM review_archive_requests WHERE id = :requestId",
                Map.of("requestId", requestId),
                Boolean.class);
        if (!Boolean.TRUE.equals(changed)) {
            return Optional.empty();
        }
        return Optional.of(jdbcTemplate.query(
                imageSelect(includeContent) + " WHERE request_id = :requestId ORDER BY sort_order",
                Map.of("requestId", requestId),
                (resultSet, rowNumber) -> new ArchiveImage(
                        resultSet.getString("id"),
                        requestId,
                        resultSet.getInt("sort_order"),
                        resultSet.getString("content_type"),
                        resultSet.getInt("width"),
                        resultSet.getInt("height"),
                        resultSet.getBytes("image_content"),
                        resultSet.getBytes("thumbnail_content"))));
    }

    private String imageSelect(boolean includeContent) {
        String contentColumn = includeContent ? "image_content" : "NULL::bytea AS image_content";
        return """
                SELECT id, sort_order, content_type, width, height,
                       %s, thumbnail_content
                FROM review_archive_request_images
                """.formatted(contentColumn);
    }
}
