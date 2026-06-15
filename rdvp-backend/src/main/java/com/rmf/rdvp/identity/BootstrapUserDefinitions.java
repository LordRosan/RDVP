package com.rmf.rdvp.identity;

import java.util.EnumSet;
import java.util.Set;

import org.springframework.security.crypto.password.PasswordEncoder;

final class BootstrapUserDefinitions {

    private BootstrapUserDefinitions() {
    }

    static Set<BootstrapUser> createUsers(PasswordEncoder passwordEncoder, String defaultPassword) {
        Set<PermissionCode> allPermissions = EnumSet.allOf(PermissionCode.class);
        return Set.of(
                create(passwordEncoder, defaultPassword, "usr-admin", "admin", "系统管理员", RoleCode.SYSTEM_ADMIN, allPermissions),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-device-admin",
                        "deviceadmin",
                        "设备管理员",
                        RoleCode.DEVICE_ADMIN,
                        PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY,
                        PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_CREATE_REQUEST_SUBMIT,
                        PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_DELETE_REQUEST_SUBMIT,
                        PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_QR_CODE_EXPORT,
                        PermissionCode.MANAGEMENT_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-field-operator",
                        "fieldoperator",
                        "现场运维人员",
                        RoleCode.FIELD_OPERATOR,
                        PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY,
                        PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_UPDATE_REQUEST_SUBMIT,
                        PermissionCode.OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT,
                        PermissionCode.OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-maintainer",
                        "maintainer",
                        "维修人员",
                        RoleCode.MAINTAINER,
                        PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY,
                        PermissionCode.OPERATIONS_CENTER_REPAIR_TASK_ACCEPT,
                        PermissionCode.OPERATIONS_CENTER_REPAIR_REPORT_SUBMIT),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-reinspector",
                        "reinspector",
                        "复检人员",
                        RoleCode.REINSPECTOR,
                        PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY,
                        PermissionCode.OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT,
                        PermissionCode.OPERATIONS_CENTER_REINSPECTION_REPORT_SUBMIT),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-auditor",
                        "auditor",
                        "监督审计人员",
                        RoleCode.SUPERVISOR_AUDITOR,
                        PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY,
                        PermissionCode.MANAGEMENT_CENTER_RECORD_QUERY),
                create(
                        passwordEncoder,
                        defaultPassword,
                        "usr-readonly",
                        "readonly",
                        "只读用户",
                        RoleCode.READ_ONLY,
                        PermissionCode.ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY));
    }

    private static BootstrapUser create(
            PasswordEncoder passwordEncoder,
            String password,
            String id,
            String username,
            String displayName,
            RoleCode role,
            PermissionCode... permissions) {
        return create(passwordEncoder, password, id, username, displayName, role, Set.of(permissions));
    }

    private static BootstrapUser create(
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


