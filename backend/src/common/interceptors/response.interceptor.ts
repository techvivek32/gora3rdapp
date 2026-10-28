import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

export interface ApiResponse<T> {
  success: boolean;
  statusCode: number;
  message: string;
  data: T;
  /** Present only for paginated handlers — see the note in `intercept`. */
  meta?: Record<string, unknown>;
  timestamp: string;
}

@Injectable()
export class ResponseInterceptor<T> implements NestInterceptor<T, ApiResponse<T>> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<ApiResponse<T>> {
    const response = context.switchToHttp().getResponse();

    return next.handle().pipe(
      map((data) => {
        // If the handler used @Res() and already wrote the response (e.g. the
        // WhatsApp webhook echoing Meta's raw hub.challenge), don't wrap/re-send.
        if (response.headersSent) {
          return data;
        }
        // If the handler already returned a formatted response, return as-is
        if (data && typeof data === 'object' && 'success' in data) {
          return data;
        }

        // Unwrapping `data` drops every sibling the handler returned, which
        // silently swallowed the pagination `meta` of anything that returns
        // buildPaginatedResult() directly — the requirements and
        // available-vehicles feeds. The app reads `hasNextPage` off that meta,
        // so with it missing the flag defaulted to false and the feed stopped
        // after the first page no matter how far you scrolled.
        //
        // Carried as a sibling rather than folded into `data`, because `data`
        // is the list itself for every existing caller.
        const meta = data && typeof data === 'object' ? (data as any).meta : undefined;

        return {
          success: true,
          statusCode: response.statusCode || 200,
          message: data?.message || 'Success',
          data: data?.data !== undefined ? data.data : data,
          ...(meta !== undefined ? { meta } : {}),
          timestamp: new Date().toISOString(),
        };
      }),
    );
  }
}
