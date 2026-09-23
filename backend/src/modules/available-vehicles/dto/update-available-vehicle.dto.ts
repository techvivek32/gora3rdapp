import { PartialType } from '@nestjs/swagger';
import { CreateAvailableVehicleDto } from './create-available-vehicle.dto';

// A real class (not `Partial<...>`) so the global ValidationPipe's
// whitelist + forbidNonWhitelisted actually runs on the update body —
// otherwise callers could inject arbitrary schema fields / Mongo operators.
export class UpdateAvailableVehicleDto extends PartialType(CreateAvailableVehicleDto) {}
