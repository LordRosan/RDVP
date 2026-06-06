package com.rmf.rdvp.audit;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@Profile("!test")
public class JdbcAuditLogRepository implements AuditLogRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcAuditLogRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void append(AuditLogCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO audit_logs (
                            id,
                            action,
                            target_id,
                            target_no,
                            actor_id,
                            actor_name,
                            status,
                            description,
                            occurred_at
                        ) VALUES (
                            :id,
                            :action,
                            :targetId,
                            :targetNo,
                            :actorId,
                            :actorName,
                            :status,
                            :description,
                            :occurredAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", create.id())
                        .addValue("action", create.action().name())
                        .addValue("targetId", blankToNull(create.targetId()))
                        .addValue("targetNo", blankToNull(create.targetNo()))
                        .addValue("actorId", blankToNull(create.actorId()))
                        .addValue("actorName", blankToNull(create.actorName()))
                        .addValue("status", create.status().name())
                        .addValue("description", blankToNull(create.description()))
                        .addValue("occurredAt", create.occurredAt()));
    }

    @Override
    public AuditLogPage list(AuditLogQuery query) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("limit", query.pageSize())
                .addValue("offset", (query.page() - 1) * query.pageSize());
        String where = buildWhereClause(query, parameters);

        List<AuditLogRecord> items = jdbcTemplate.query(
                """
                        SELECT id, action, target_id, target_no, actor_id, actor_name, status, description, occurred_at
                        FROM audit_logs
                        """
                        + where
                        + " ORDER BY occurred_at DESC, id DESC LIMIT :limit OFFSET :offset",
                parameters,
                this::mapRecord);
        Long total = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM audit_logs" + where,
                parameters,
                Long.class);
        return new AuditLogPage(items, total == null ? 0 : total);
    }

    private String buildWhereClause(AuditLogQuery query, MapSqlParameterSource parameters) {
        List<String> conditions = new ArrayList<>();
        if (query.action() != null) {
            conditions.add("action = :action");
            parameters.addValue("action", query.action().name());
        }
        if (query.keyword() != null) {
            conditions.add("""
                    (
                        target_id ILIKE :keyword ESCAPE '\\'
                        OR target_no ILIKE :keyword ESCAPE '\\'
                        OR actor_name ILIKE :keyword ESCAPE '\\'
                        OR description ILIKE :keyword ESCAPE '\\'
                    )
                    """);
            parameters.addValue("keyword", "%" + escapeLikeKeyword(query.keyword()) + "%");
        }

        return conditions.isEmpty() ? "" : " WHERE " + String.join(" AND ", conditions);
    }

    private AuditLogRecord mapRecord(ResultSet resultSet, int rowNumber) throws SQLException {
        return new AuditLogRecord(
                resultSet.getString("id"),
                AuditAction.valueOf(resultSet.getString("action")),
                resultSet.getString("target_id"),
                resultSet.getString("target_no"),
                resultSet.getString("actor_id"),
                resultSet.getString("actor_name"),
                AuditStatus.valueOf(resultSet.getString("status")),
                resultSet.getString("description"),
                resultSet.getObject("occurred_at", OffsetDateTime.class));
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }

    private String escapeLikeKeyword(String value) {
        return value.replace("\\", "\\\\")
                .replace("%", "\\%")
                .replace("_", "\\_");
    }
}
