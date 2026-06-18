package com.rmf.rdvp.records;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.rmf.rdvp.api.common.ApiResponse;
import com.rmf.rdvp.api.common.RequestIds;
import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;
import com.rmf.rdvp.identity.AuthenticatedUser;
import com.rmf.rdvp.identity.PermissionCode;

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api/v1")
public class RecordQueryController {

    private final RecordQueryService recordQueryService;

    public RecordQueryController(RecordQueryService recordQueryService) {
        this.recordQueryService = recordQueryService;
    }

    @GetMapping("/operation-records")
    public ResponseEntity<ApiResponse<RecordListResponse>> queryOperationRecords(
            @RequestParam String category,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            Authentication authentication,
            HttpServletRequest request) {
        AuthenticatedUser user = requireUser(authentication);
        var normalizedCategory = normalizeCategory(category);
        requireCategoryPermission(user, normalizedCategory);
        var result = recordQueryService.queryRecords(normalizedCategory, type, keyword, page, pageSize);
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
            case "ARCHIVE" -> PermissionCode.MANAGEMENT_CENTER_ARCHIVE_RECORD_QUERY;
            case "OPERATIONS" -> PermissionCode.MANAGEMENT_CENTER_OPERATION_RECORD_QUERY;
            case "REVIEW" -> PermissionCode.MANAGEMENT_CENTER_REVIEW_RECORD_QUERY;
            default -> throw new BusinessException(ErrorCode.BAD_REQUEST, "category is invalid.");
        };

        if (!user.permissions().contains(requiredPermission)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }
    }
}
