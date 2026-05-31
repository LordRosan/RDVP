package com.rmf.rdvp.api.common;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.rmf.rdvp.domain.common.BusinessException;
import com.rmf.rdvp.domain.common.ErrorCode;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    ResponseEntity<ApiResponse<Void>> handleBusinessException(BusinessException exception, HttpServletRequest request) {
        ErrorCode errorCode = exception.getErrorCode();
        return build(errorCode.status(), errorCode.code(), exception.getMessage(), request, exception.getDetails());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiResponse<Void>> handleMethodArgumentNotValid(
            MethodArgumentNotValidException exception,
            HttpServletRequest request) {
        List<ValidationError> details = exception.getBindingResult()
                .getFieldErrors()
                .stream()
                .map(this::toValidationError)
                .toList();
        return build(
                ErrorCode.VALIDATION_FAILED.status(),
                ErrorCode.VALIDATION_FAILED.code(),
                ErrorCode.VALIDATION_FAILED.defaultMessage(),
                request,
                details);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    ResponseEntity<ApiResponse<Void>> handleConstraintViolation(
            ConstraintViolationException exception,
            HttpServletRequest request) {
        List<ValidationError> details = exception.getConstraintViolations()
                .stream()
                .map(violation -> new ValidationError(
                        violation.getPropertyPath().toString(),
                        violation.getMessage()))
                .toList();
        return build(
                ErrorCode.VALIDATION_FAILED.status(),
                ErrorCode.VALIDATION_FAILED.code(),
                ErrorCode.VALIDATION_FAILED.defaultMessage(),
                request,
                details);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ApiResponse<Void>> handleUnreadableMessage(HttpMessageNotReadableException exception, HttpServletRequest request) {
        return build(
                ErrorCode.BAD_REQUEST.status(),
                ErrorCode.BAD_REQUEST.code(),
                "Request body is invalid.",
                request,
                null);
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiResponse<Void>> handleUnexpected(Exception exception, HttpServletRequest request) {
        return build(
                ErrorCode.INTERNAL_ERROR.status(),
                ErrorCode.INTERNAL_ERROR.code(),
                ErrorCode.INTERNAL_ERROR.defaultMessage(),
                request,
                null);
    }

    private ResponseEntity<ApiResponse<Void>> build(
            HttpStatus status,
            String code,
            String message,
            HttpServletRequest request,
            Object details) {
        ApiError error = new ApiError(code, message, details);
        return ResponseEntity.status(status).body(ApiResponse.failure(error, RequestIds.resolve(request)));
    }

    private ValidationError toValidationError(FieldError fieldError) {
        return new ValidationError(fieldError.getField(), fieldError.getDefaultMessage());
    }

    private record ValidationError(String field, String message) {
    }
}
