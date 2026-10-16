import { BadRequestException, Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { SettingsService } from '../settings/settings.service';
import { matchNames, NameMatchResult } from '../../common/utils/name-match.util';

/**
 * Government-record lookups (vehicle RC, and DigiLocker for the person).
 *
 * Deliberately provider-agnostic: every call goes through one `post()` helper and
 * the endpoints/field names live in one place, so swapping vendor means editing
 * this file only. Cashfree is the default because it carries RC, DL and the
 * DigiLocker flow under a single account.
 *
 * When no API key is configured the service reports `configured: false` instead
 * of throwing, so the app falls back to manual entry and nothing is blocked while
 * the client is still signing up with a vendor.
 */

export interface RcLookupResult {
  configured: boolean;
  found: boolean;
  /** Normalised vehicle fields, ready to drop into the garage form. */
  vehicle?: {
    registrationNumber: string;
    ownerName: string;
    modelName: string;
    vehicleType: string;
    fuelType: string;
    seatingCapacity: number;
    color: string;
    registeredAt?: string;
    insuranceValidUpto?: string;
    fitnessValidUpto?: string;
    blacklisted?: boolean;
  };
  /** Present when we had a name to compare against. */
  nameMatch?: NameMatchResult;
  message: string;
}

export interface DigilockerStartResult {
  configured: boolean;
  /** Hosted URL the app opens; the user does the Aadhaar OTP there. */
  url?: string;
  requestId?: string;
  message: string;
}

export interface DigilockerResult {
  configured: boolean;
  verified: boolean;
  person?: {
    fullName: string;
    dob?: string;
    gender?: string;
    address?: string;
    /** Last 4 only — we never store a full Aadhaar number. */
    aadhaarLast4?: string;
    dlNumber?: string;
    dlValidUpto?: string;
    photo?: string;
  };
  message: string;
}

@Injectable()
export class VerificationService {
  private readonly logger = new Logger(VerificationService.name);

  constructor(private readonly settings: SettingsService) {}

  private async creds(): Promise<{ baseUrl: string; clientId: string; clientSecret: string } | null> {
    const s: any = await this.settings.getSettings();
    const clientId = (s?.verifyClientId || '').trim();
    const clientSecret = (s?.verifyClientSecret || '').trim();
    if (!clientId || !clientSecret) return null;
    // Sandbox and production differ only by host, so the admin picks the mode.
    // VERIFY_BASE_URL overrides both — used to point at a staging or mock vendor
    // without touching code, and the one hook needed to swap providers.
    const baseUrl =
      (process.env.VERIFY_BASE_URL || '').trim() ||
      (s?.verifySandbox === false
        ? 'https://api.cashfree.com/verification'
        : 'https://sandbox.cashfree.com/verification');
    return { baseUrl, clientId, clientSecret };
  }

  /** One place that knows how to talk to the vendor. */
  private async post(path: string, body: any): Promise<any> {
    const c = await this.creds();
    if (!c) return null;
    let res: Response;
    try {
      res = await fetch(`${c.baseUrl}${path}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-client-id': c.clientId,
          'x-client-secret': c.clientSecret,
        },
        body: JSON.stringify(body),
        // A driver is waiting on this screen - don't hang on a dead vendor.
        signal: AbortSignal.timeout(15_000),
      });
    } catch (e: any) {
      // Refused, DNS failure, timeout. Nothing the user can act on, so say what
      // they should do instead rather than leaking a network error.
      this.logger.warn(`verification ${path} unreachable: ${e?.message || e}`);
      throw new ServiceUnavailableException(
        'Verification service is unreachable right now - enter the details manually.',
      );
    }
    const json: any = await res.json().catch(() => ({}));
    if (!res.ok) {
      this.logger.warn(`verification ${path} -> ${res.status} ${JSON.stringify(json).slice(0, 200)}`);
      throw new BadRequestException(json?.message || 'Verification service refused the request');
    }
    return json;
  }

  /** Registration numbers come in with spaces/dashes/lowercase; the API wants none. */
  private normaliseRc(raw: string): string {
    return (raw || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
  }

  /**
   * Vehicle RC lookup. `claimedName` is the account holder's name — when given,
   * the result carries a name-match verdict so the app can gate the save.
   */
  async lookupRc(registrationNumber: string, claimedName?: string): Promise<RcLookupResult> {
    const rc = this.normaliseRc(registrationNumber);
    if (rc.length < 6) throw new BadRequestException('Enter a valid registration number');

    const c = await this.creds();
    if (!c) {
      return {
        configured: false,
        found: false,
        message: 'Automatic RC lookup is not set up yet — enter the details manually.',
      };
    }

    const json = await this.post('/vehicle-rc', { vehicle_number: rc });
    const d = json?.data ?? json ?? {};
    const ownerName = (d.owner_name || d.ownerName || '').trim();
    if (!ownerName && !d.maker_model && !d.makerModel) {
      return { configured: true, found: false, message: 'No record found for this registration number' };
    }

    const seats = Number(d.seating_capacity ?? d.seatingCapacity ?? 0) || 0;
    const result: RcLookupResult = {
      configured: true,
      found: true,
      vehicle: {
        registrationNumber: rc,
        ownerName,
        modelName: (d.maker_model || d.makerModel || d.model || '').trim(),
        vehicleType: (d.vehicle_class || d.vehicleClass || d.category || '').trim(),
        fuelType: (d.fuel_type || d.fuelType || '').trim(),
        seatingCapacity: seats,
        color: (d.color || d.colour || '').trim(),
        registeredAt: d.registration_date || d.registrationDate,
        insuranceValidUpto: d.insurance_validity || d.insuranceValidity,
        fitnessValidUpto: d.fitness_upto || d.fitnessUpto,
        blacklisted: Boolean(d.blacklist_status || d.blacklistStatus),
      },
      message: 'Vehicle details fetched',
    };

    if (claimedName && ownerName) {
      result.nameMatch = matchNames(ownerName, claimedName);
      result.message = result.nameMatch.matched
        ? 'Vehicle details fetched — owner name matches'
        : 'Vehicle details fetched — owner name does NOT match your account';
    }
    return result;
  }

  /**
   * Start a DigiLocker session. The user completes Aadhaar OTP on the hosted page,
   * which is what proves the DL and Aadhaar belong to the person holding the phone.
   * (UIDAI no longer lets third parties run Aadhaar OTP directly — DigiLocker is
   * the supported route.)
   */
  async startDigilocker(userId: string, redirectUrl?: string): Promise<DigilockerStartResult> {
    const c = await this.creds();
    if (!c) {
      return {
        configured: false,
        message: 'DigiLocker verification is not set up yet — enter the details manually.',
      };
    }
    const json = await this.post('/digilocker', {
      verification_id: `gora_${userId}_${Date.now()}`,
      document_requested: ['AADHAAR', 'DRIVING_LICENSE'],
      redirect_url: redirectUrl || 'https://backend.goracabs.com/digilocker/done',
    });
    const d = json?.data ?? json ?? {};
    return {
      configured: true,
      url: d.url || d.consent_url,
      requestId: d.verification_id || d.ref_id,
      message: 'Open the link and verify with the OTP sent to your Aadhaar-linked mobile',
    };
  }

  /** Read back a completed DigiLocker session. */
  async fetchDigilocker(requestId: string): Promise<DigilockerResult> {
    const c = await this.creds();
    if (!c) {
      return { configured: false, verified: false, message: 'DigiLocker verification is not set up yet' };
    }
    const json = await this.post('/digilocker/document', { verification_id: requestId });
    const d = json?.data ?? json ?? {};
    const status = (d.status || '').toString().toUpperCase();
    if (status && !['SUCCESS', 'VALID', 'COMPLETED'].includes(status)) {
      return { configured: true, verified: false, message: 'Verification not completed yet' };
    }
    const aadhaar = (d.aadhaar_number || d.aadhaarNumber || '').toString();
    return {
      configured: true,
      verified: true,
      person: {
        fullName: (d.name || d.full_name || '').trim(),
        dob: d.dob || d.date_of_birth,
        gender: d.gender,
        address: (d.address || '').toString().trim(),
        // Store only the last 4 — a full Aadhaar number is not ours to keep.
        aadhaarLast4: aadhaar ? aadhaar.slice(-4) : undefined,
        dlNumber: (d.dl_number || d.driving_license_number || '').trim() || undefined,
        dlValidUpto: d.dl_validity || d.doe,
        photo: d.photo || d.profile_image,
      },
      message: 'Identity verified via DigiLocker',
    };
  }
}
