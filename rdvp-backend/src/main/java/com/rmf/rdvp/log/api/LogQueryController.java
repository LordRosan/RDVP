package com.rmf.rdvp.log.api;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.log.LogList;
import com.rmf.rdvp.log.LogQueryService;
import com.rmf.rdvp.shared.api.ApiResponse;
import com.rmf.rdvp.shared.api.RequestIds;
import com.rmf.rdvp.shared.error.BusinessException;
import com.rmf.rdvp.shared.error.ErrorCode;
import com.rmf.rdvp.user.AuthenticatedUser;
import com.rmf.rdvp.user.PermissionCode;

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api/v1")
public class LogQueryController {

    private final LogQueryService logQueryService;

    public LogQueryController(LogQueryService logQueryService) {
        this.logQueryService = logQueryService;
    }

    @GetMapping("/log-center/logs")
    public ResponseEntity<ApiResponse<LogList>> queryLogCenterLogs(
            @RequestParam String category,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            Authentication authentication,
            HttpServletRequest request) {
        AuthenticatedUser user = requireUser(authentication);
        var normalizedCategory = normalizeCategory(category);
        requireCategoryPermission(user, normalizedCategory);
        var result = logQueryService.queryLogs(normalizedCategory, type, keyword, startDate, endDate, page, pageSize);
        return ResponseEntity.ok(ApiResponse.success(result, RequestIds.resolve(request)));
    }

    private AuthenticatedUser requireUser(Authentication authentication) {
        if (authentication == null || !(authentication.getPrincipal() instanceof AuthenticatedUser user)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }

        return user;
    }

    private String normalizeCategory(String category) {
        if (category == null || category.isBlank()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "category is required.");
        }

        return category.trim().toUpperCase();
    }

    private void requireCategoryPermission(AuthenticatedUser user, String category) {
        PermissionCode requiredPermission = switch (category) {
            case "ARCHIVE_OPERATION" -> PermissionCode.LOG_CENTER_ARCHIVE_OPERATION_LOG_QUERY;
            case "ARCHIVE_REVIEW" -> PermissionCode.LOG_CENTER_ARCHIVE_REVIEW_LOG_QUERY;
            case "OPERATIONS_OPERATION" -> PermissionCode.LOG_CENTER_OPERATIONS_OPERATION_LOG_QUERY;
            case "OPERATIONS_REVIEW" -> PermissionCode.LOG_CENTER_OPERATIONS_REVIEW_LOG_QUERY;
            default -> throw new BusinessException(ErrorCode.BAD_REQUEST, "category is invalid.");
        };

        if (!user.permissions().contains(requiredPermission)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
    }
}
