package com.rmf.rdvp.api.auth;

import java.util.List;

import com.rmf.rdvp.identity.AuthenticatedUser;

public record UserResponse(
        String id,
        String username,
        String displayName,
        List<String> roles,
        List<String> permissions) {

    public static UserResponse from(AuthenticatedUser user) {
        return new UserResponse(
                user.id(),
                user.username(),
                user.displayName(),
                user.roles().stream().map(Enum::name).sorted().toList(),
                user.permissions().stream().map(Enum::name).sorted().toList());
    }
}
