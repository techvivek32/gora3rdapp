import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

export interface ApiResponse<T> {
  success: boolean;
  statusCode: number;
  message: string;
  data: T;
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

        return {
          success: true,
          statusCode: response.statusCode || 200,
          message: data?.message || 'Success',
          data: data?.data !== undefined ? data.data : data,
          timestamp: new Date().toISOString(),
        };
      }),
    );
  }
}
