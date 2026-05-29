export class AppError extends Error {
  readonly code: string;
  readonly httpStatus: number;
  readonly details: Record<string, unknown>;

  constructor(code: string, message: string, httpStatus = 400, details: Record<string, unknown> = {}) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.httpStatus = httpStatus;
    this.details = details;
  }
}

export function badRequest(code: string, message: string, details: Record<string, unknown> = {}): AppError {
  return new AppError(code, message, 400, details);
}

export function unauthorized(message = 'Authentication is required.'): AppError {
  return new AppError('UNAUTHORIZED', message, 401);
}

export function forbidden(message = 'Permission denied.'): AppError {
  return new AppError('FORBIDDEN', message, 403);
}

export function notFound(code: string, message: string): AppError {
  return new AppError(code, message, 404);
}

export function conflict(code: string, message: string): AppError {
  return new AppError(code, message, 409);
}

export function validationFailed(code: string, message: string, details: Record<string, unknown> = {}): AppError {
  return new AppError(code, message, 422, details);
}

export function isAppError(value: unknown): value is AppError {
  return value instanceof AppError;
}
