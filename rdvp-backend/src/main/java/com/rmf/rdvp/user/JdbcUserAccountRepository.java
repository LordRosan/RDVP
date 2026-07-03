package com.rmf.rdvp.user;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

@Repository
@Profile("!test")
public class JdbcUserAccountRepository implements UserAccountRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;

    public JdbcUserAccountRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public Optional<BootstrapUser> findByUsername(String username) {
        String normalizedUsername = username == null ? "" : username.trim().toLowerCase();
        if (normalizedUsername.isEmpty()) {
            return Optional.empty();
        }

        return findOne(
                """
                        SELECT id, username, password_hash, display_name, status
                        FROM user_accounts
                        WHERE username = :username
                        """,
                Map.of("username", normalizedUsername));
    }

    @Override
    public Optional<BootstrapUser> findById(String id) {
        String normalizedId = id == null ? "" : id.trim();
        if (normalizedId.isEmpty()) {
            return Optional.empty();
        }

        return findOne(
                """
                        SELECT id, username, password_hash, display_name, status
                        FROM user_accounts
                        WHERE id = :id
                        """,
                Map.of("id", normalizedId));
    }

    @Transactional
    public void ensureBootstrapUser(BootstrapUser user) {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        if (findById(user.id()).isEmpty()) {
            insertUser(user, now);
        } else {
            updateBootstrapUserMetadata(user, now);
        }

        replaceRoles(user);
        replacePermissions(user);
    }

    private Optional<BootstrapUser> findOne(String sql, Map<String, ?> parameters) {
        var results = jdbcTemplate.query(sql, parameters, this::mapUser);
        return results.stream().findFirst();
    }

    private BootstrapUser mapUser(ResultSet resultSet, int rowNumber) throws SQLException {
        String userId = resultSet.getString("id");
        return new BootstrapUser(
                userId,
                resultSet.getString("username"),
                resultSet.getString("password_hash"),
                resultSet.getString("display_name"),
                UserStatus.valueOf(resultSet.getString("status")),
                findRoles(userId),
                findPermissions(userId));
    }

    private Set<RoleCode> findRoles(String userId) {
        return jdbcTemplate.queryForList(
                        "SELECT role_code FROM user_account_roles WHERE user_id = :userId",
                        Map.of("userId", userId),
                        String.class)
                .stream()
                .map(RoleCode::fromCode)
                .collect(Collectors.toUnmodifiableSet());
    }

    private Set<PermissionCode> findPermissions(String userId) {
        return jdbcTemplate.queryForList(
                        "SELECT permission_code FROM user_account_permissions WHERE user_id = :userId",
                        Map.of("userId", userId),
                        String.class)
                .stream()
                .map(PermissionCode::valueOf)
                .collect(Collectors.toUnmodifiableSet());
    }

    private void insertUser(BootstrapUser user, OffsetDateTime now) {
        jdbcTemplate.update(
                """
                        INSERT INTO user_accounts (
                            id, username, password_hash, display_name, status, created_at, updated_at
                        ) VALUES (
                            :id, :username, :passwordHash, :displayName, :status, :createdAt, :updatedAt
                        )
                        """,
                new MapSqlParameterSource()
                        .addValue("id", user.id())
                        .addValue("username", user.username())
                        .addValue("passwordHash", user.passwordHash())
                        .addValue("displayName", user.displayName())
                        .addValue("status", user.status().name())
                        .addValue("createdAt", now)
                        .addValue("updatedAt", now));
    }

    private void updateBootstrapUserMetadata(BootstrapUser user, OffsetDateTime now) {
        jdbcTemplate.update(
                """
                        UPDATE user_accounts
                        SET username = :username,
                            display_name = :displayName,
                            status = :status,
                            updated_at = :updatedAt
                        WHERE id = :id
                        """,
                new MapSqlParameterSource()
                        .addValue("id", user.id())
                        .addValue("username", user.username())
                        .addValue("displayName", user.displayName())
                        .addValue("status", user.status().name())
                        .addValue("updatedAt", now));
    }

    private void replaceRoles(BootstrapUser user) {
        jdbcTemplate.update("DELETE FROM user_account_roles WHERE user_id = :userId", Map.of("userId", user.id()));
        for (RoleCode role : user.roles()) {
            jdbcTemplate.update(
                    """
                            INSERT INTO user_account_roles (user_id, role_code)
                            VALUES (:userId, :roleCode)
                            ON CONFLICT (user_id, role_code) DO NOTHING
                            """,
                    Map.of("userId", user.id(), "roleCode", role.code()));
        }
    }

    private void replacePermissions(BootstrapUser user) {
        jdbcTemplate.update("DELETE FROM user_account_permissions WHERE user_id = :userId", Map.of("userId", user.id()));
        for (PermissionCode permission : user.permissions()) {
            jdbcTemplate.update(
                    """
                            INSERT INTO user_account_permissions (user_id, permission_code)
                            VALUES (:userId, :permissionCode)
                            ON CONFLICT (user_id, permission_code) DO NOTHING
                            """,
                    Map.of("userId", user.id(), "permissionCode", permission.name()));
        }
    }
}
