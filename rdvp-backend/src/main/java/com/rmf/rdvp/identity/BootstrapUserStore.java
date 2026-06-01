package com.rmf.rdvp.identity;

import java.util.EnumSet;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Repository;

import com.rmf.rdvp.config.RdvpRuntimeProperties;

@Repository
public class BootstrapUserStore {

    private final Map<String, BootstrapUser> usersById;
    private final Map<String, BootstrapUser> usersByUsername;

    public BootstrapUserStore(PasswordEncoder passwordEncoder, RdvpRuntimeProperties runtimeProperties) {
        String defaultPassword = runtimeProperties.getBootstrapUsers().getDefaultPassword();
        Set<PermissionCode> allPermissions = EnumSet.allOf(PermissionCode.class);
        Set<BootstrapUser> users = Set.of(
                create(passwordEncoder, defaultPassword, "usr-admin", "admin", "系统管理员", RoleCode.SYSTEM_ADMIN, allPermissions),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-device-admin",
                        "deviceadmin",
                        "设备管理员",
                        RoleCode.DEVICE_ADMIN,
                        PermissionCode.ARCHIVE_DEVICE_READ,
                        PermissionCode.ARCHIVE_DEVICE_CREATE,
                        PermissionCode.ARCHIVE_DEVICE_DELETE,
                        PermissionCode.MGMT_ARCHIVE_CHANGE_REVIEW),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-field-operator",
                        "fieldoperator",
                        "现场运维人员",
                        RoleCode.FIELD_OPERATOR,
                        PermissionCode.ARCHIVE_DEVICE_READ,
                        PermissionCode.ARCHIVE_CHANGE_REQUEST_CREATE,
                        PermissionCode.OPS_DEVICE_VERIFY,
                        PermissionCode.OPS_FAULT_REPORT_CREATE),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-maintainer",
                        "maintainer",
                        "维修人员",
                        RoleCode.MAINTAINER,
                        PermissionCode.ARCHIVE_DEVICE_READ,
                        PermissionCode.OPS_REPAIR_TASK_ACCEPT,
                        PermissionCode.OPS_REPAIR_REPORT_CREATE),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-reinspector",
                        "reinspector",
                        "复检人员",
                        RoleCode.REINSPECTOR,
                        PermissionCode.ARCHIVE_DEVICE_READ,
                        PermissionCode.OPS_REINSPECTION_CREATE),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-auditor",
                        "auditor",
                        "监督审计人员",
                        RoleCode.SUPERVISOR_AUDITOR,
                        PermissionCode.ARCHIVE_DEVICE_READ,
                        PermissionCode.MGMT_AUDIT_LOG_READ),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-readonly",
                        "readonly",
                        "只读用户",
                        RoleCode.READ_ONLY,
                        PermissionCode.ARCHIVE_DEVICE_READ));

        this.usersById = users.stream().collect(Collectors.toUnmodifiableMap(BootstrapUser::id, Function.identity()));
        this.usersByUsername = users.stream()
                .collect(Collectors.toUnmodifiableMap(BootstrapUser::username, Function.identity()));
    }

    public Optional<BootstrapUser> findByUsername(String username) {
        return Optional.ofNullable(usersByUsername.get(username));
    }

    public Optional<BootstrapUser> findById(String id) {
        return Optional.ofNullable(usersById.get(id));
    }

    private BootstrapUser create(
            PasswordEncoder passwordEncoder,
            String password,
            String id,
            String username,
            String displayName,
            RoleCode role,
            PermissionCode... permissions) {
        return create(passwordEncoder, password, id, username, displayName, role, Set.of(permissions));
    }

    private BootstrapUser create(
            PasswordEncoder passwordEncoder,
            String password,
            String id,
            String username,
            String displayName,
            RoleCode role,
            Set<PermissionCode> permissions) {
        return new BootstrapUser(
                id,
                username,
                passwordEncoder.encode(password),
                displayName,
                UserStatus.ACTIVE,
                Set.of(role),
                Set.copyOf(permissions));
    }
}
