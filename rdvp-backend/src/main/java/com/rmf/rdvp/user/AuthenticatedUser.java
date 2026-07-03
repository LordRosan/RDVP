package com.rmf.rdvp.user;

import java.util.Set;

public record AuthenticatedUser(
        String id,
        String username,
        String displayName,
        UserStatus status,
        Set<RoleCode> roles,
        Set<PermissionCode> permissions) {
}
