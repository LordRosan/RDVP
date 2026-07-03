package com.rmf.rdvp.user.api;

import java.util.List;

import com.rmf.rdvp.user.AuthenticatedUser;

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
                user.roles().stream().map(role -> role.code()).sorted().toList(),
                user.permissions().stream().map(Enum::name).sorted().toList());
    }
}
