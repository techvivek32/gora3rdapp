import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  /** Mongoose throws this when a path like `_id` gets a value it can't cast. */
  private isCastError(exception: unknown): boolean {
    return exception instanceof Error && exception.name === 'CastError';
  }

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let errors: any = null;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse() as any;

      if (typeof exceptionResponse === 'string') {
        message = exceptionResponse;
      } else {
        message = exceptionResponse.message || exceptionResponse.error || message;
        errors = exceptionResponse.errors || null;
      }
    } else if (this.isCastError(exception)) {
      // A malformed :id (not a valid ObjectId) is a bad URL, not a server fault.
      status = HttpStatus.NOT_FOUND;
      message = 'Not found';
    } else if (exception instanceof Error) {
      // Never surface the raw error text — it leaks model/schema internals. The
      // full message and stack still go to the server log below.
      this.logger.error(`Unhandled exception: ${exception.message}`, exception.stack);
    }

    // Don't log 401/403 as errors
    if (status >= 500) {
      this.logger.error(
        `${request.method} ${request.url} - ${status}: ${message}`,
        exception instanceof Error ? exception.stack : undefined,
      );
    }

    response.status(status).json({
      success: false,
      statusCode: status,
      message,
      errors,
      timestamp: new Date().toISOString(),
      path: request.url,
    });
  }
}
