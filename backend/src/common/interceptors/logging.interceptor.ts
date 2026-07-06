import { Injectable, NestInterceptor, ExecutionContext, CallHandler, Logger } from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  private readonly isProd = process.env.NODE_ENV === 'production';

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest();
    const { method, url, ip } = req;
    const userAgent = req.get('user-agent') || '';
    const now = Date.now();

    return next.handle().pipe(
      tap(() => {
        const res = context.switchToHttp().getResponse();
        const delay = Date.now() - now;
        // Production: only log slow requests (>1s) to save CPU/disk. Dev: log all.
        if (!this.isProd) {
          this.logger.log(`${method} ${url} ${res.statusCode} ${delay}ms - ${ip} ${userAgent}`);
        } else if (delay > 1000) {
          this.logger.warn(`SLOW ${method} ${url} ${res.statusCode} ${delay}ms`);
        }
      }),
    );
  }
}
