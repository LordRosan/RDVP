package com.rmf.rdvp.identity;

import java.util.Set;

public record AuthenticatedUser(
        String id,
        String username,
        String displayName,
        UserStatus status,
        Set<RoleCode> roles,
        Set<PermissionCode> permissions) {
}
