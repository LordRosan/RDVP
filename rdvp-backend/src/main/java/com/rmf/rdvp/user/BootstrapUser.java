package com.rmf.rdvp.user;

import java.util.Set;

public record BootstrapUser(
        String id,
        String username,
        String passwordHash,
        String displayName,
        UserStatus status,
        Set<RoleCode> roles,
        Set<PermissionCode> permissions) {

    public AuthenticatedUser toAuthenticatedUser() {
        return new AuthenticatedUser(id, username, displayName, status, roles, permissions);
    }
}
