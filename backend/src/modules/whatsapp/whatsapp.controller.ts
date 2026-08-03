import { Body, Controller, Get, HttpCode, Post, Query, Res } from '@nestjs/common';
import { Response } from 'express';
import { ApiExcludeController } from '@nestjs/swagger';
import { Public } from '../../common/decorators/roles.decorator';
import { WhatsappService } from './whatsapp.service';

/**
 * WhatsApp Cloud API webhook. Meta calls GET once to verify, then POSTs every
 * inbound message here. A correctly-formatted booking message becomes a live
 * Requirement in the app.
 */
@ApiExcludeController()
@Controller('whatsapp')
export class WhatsappController {
  constructor(private readonly whatsapp: WhatsappService) {}

  @Get('webhook')
  @Public()
  verify(
    @Query('hub.mode') mode: string,
    @Query('hub.verify_token') token: string,
    @Query('hub.challenge') challenge: string,
    @Res() res: Response,
  ) {
    // Meta expects the raw challenge string echoed back (not JSON).
    const out = this.whatsapp.verify(mode, token, challenge);
    return res.status(200).send(out);
  }

  @Post('webhook')
  @Public()
  @HttpCode(200)
  async receive(@Body() body: any) {
    // Ack immediately; do the work in the background so Meta never retries.
    this.whatsapp.handleWebhook(body).catch(() => {});
    return { received: true };
  }
}
