package com.rmf.rdvp.log;

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
public class JdbcLogEntryRepository implements LogEntryRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcLogEntryRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void append(LogEntryCreate create) {
        jdbcTemplate.update(
                """
                        INSERT INTO log_entries (
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
    public LogEntryPage list(LogEntryQuery query) {
        MapSqlParameterSource parameters = new MapSqlParameterSource()
                .addValue("limit", query.pageSize())
                .addValue("offset", (query.page() - 1) * query.pageSize());
        String where = buildWhereClause(query, parameters);

        List<LogEntry> items = jdbcTemplate.query(
                """
                        SELECT id, action, target_id, target_no, actor_id, actor_name, status, description, occurred_at
                        FROM log_entries
                        """
                        + where
                        + " ORDER BY occurred_at DESC, id DESC LIMIT :limit OFFSET :offset",
                parameters,
                this::mapRecord);
        Long total = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM log_entries" + where,
                parameters,
                Long.class);
        return new LogEntryPage(items, total == null ? 0 : total);
    }

    @Override
    public long countSuccessByAction(LogAction action) {
        Long count = jdbcTemplate.queryForObject(
                """
                        SELECT count(*)
                        FROM log_entries
                        WHERE action = :action
                          AND status = 'SUCCESS'
                        """,
                new MapSqlParameterSource()
                        .addValue("action", action.name()),
                Long.class);
        return count == null ? 0 : count;
    }

    private String buildWhereClause(LogEntryQuery query, MapSqlParameterSource parameters) {
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

    private LogEntry mapRecord(ResultSet resultSet, int rowNumber) throws SQLException {
        return new LogEntry(
                resultSet.getString("id"),
                LogAction.valueOf(resultSet.getString("action")),
                resultSet.getString("target_id"),
                resultSet.getString("target_no"),
                resultSet.getString("actor_id"),
                resultSet.getString("actor_name"),
                LogEntryStatus.valueOf(resultSet.getString("status")),
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
