import { IncomingMessage, ServerResponse } from 'node:http';
import { randomUUID } from 'node:crypto';
import { AppError, isAppError } from '../domain/errors.js';

export interface ApiRequestContext {
  requestId: string;
}

export function createRequestContext(request: IncomingMessage): ApiRequestContext {
  const requestIdHeader = request.headers['x-request-id'];
  const requestId = (Array.isArray(requestIdHeader)
    ? requestIdHeader[0]
    : requestIdHeader) ?? `req_${randomUUID()}`;
  return { requestId };
}

export async function readJsonBody<T>(request: IncomingMessage): Promise<T> {
  const chunks: Buffer[] = [];
  for await (const chunk of request) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }

  if (chunks.length === 0) {
    return {} as T;
  }

  const bodyText = Buffer.concat(chunks).toString('utf8').trim();
  if (bodyText.length === 0) {
    return {} as T;
  }

  return JSON.parse(bodyText) as T;
}

export function sendSuccess(response: ServerResponse, statusCode: number, data: unknown, requestId: string): void {
  sendJson(response, statusCode, {
    success: true,
    data,
    requestId,
    timestamp: new Date().toISOString()
  });
}

export function sendError(response: ServerResponse, error: unknown, requestId: string): void {
  if (isAppError(error)) {
    sendJson(response, error.httpStatus, {
      success: false,
      error: {
        code: error.code,
        message: error.message,
        details: error.details
      },
      requestId,
      timestamp: new Date().toISOString()
    });
    return;
  }

  if (error instanceof SyntaxError) {
    const appError = new AppError('BAD_REQUEST', 'Request body must be valid JSON.', 400);
    sendError(response, appError, requestId);
    return;
  }

  sendJson(response, 500, {
    success: false,
    error: {
      code: 'INTERNAL_ERROR',
      message: 'Internal server error.',
      details: {}
    },
    requestId,
    timestamp: new Date().toISOString()
  });
}

function sendJson(response: ServerResponse, statusCode: number, body: unknown): void {
  response.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store'
  });
  response.end(JSON.stringify(body));
}
