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

export interface DlLookupResult {
  configured: boolean;
  found: boolean;
  /** Normalised licence fields, ready to drop into the driver form. */
  licence?: {
    dlNumber: string;
    holderName: string;
    dob?: string;
    gender?: string;
    address?: string;
    issuedOn?: string;
    validUpto?: string;
    /** "LMV", "MCWG", "TRANS" - what they are allowed to drive. */
    vehicleClasses?: string[];
    rto?: string;
    /** True when the licence has expired as of today. */
    expired?: boolean;
  };
  message: string;
}

export interface OcrResult {
  configured: boolean;
  found: boolean;
  document?: {
    type: string;
    name?: string;
    dob?: string;
    gender?: string;
    address?: string;
    /** Last 4 only - a full Aadhaar number is not ours to keep. */
    aadhaarLast4?: string;
    idNumber?: string;
  };
  /** Vendor's read on whether the image can be trusted at all. */
  quality?: {
    blurred?: boolean;
    glare?: boolean;
    /** A photo of a screen, or a digitally altered image. */
    screenshot?: boolean;
    tampered?: boolean;
  };
  /** Present when we had a name to compare the document against. */
  nameMatch?: NameMatchResult;
  message: string;
}

@Injectable()
export class VerificationService {
  private readonly logger = new Logger(VerificationService.name);

  /** Answers already paid for, by lookup key. */
  private readonly _cache = new Map<string, { at: number; value: any }>();
  /** Long enough to cover a form being filled in, short enough to stay current. */
  private static readonly CACHE_MS = 15 * 60 * 1000;

  private cached<T>(key: string): T | null {
    const hit = this._cache.get(key);
    if (!hit) return null;
    if (Date.now() - hit.at > VerificationService.CACHE_MS) {
      this._cache.delete(key);
      return null;
    }
    return hit.value as T;
  }

  private remember(key: string, value: any): void {
    // Keep it bounded - this is a cost saver, not a datastore.
    if (this._cache.size > 500) {
      const oldest = [...this._cache.entries()].sort((a, b) => a[1].at - b[1].at)[0];
      if (oldest) this._cache.delete(oldest[0]);
    }
    this._cache.set(key, { at: Date.now(), value });
  }

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

  /** The OCR endpoint wants the file itself, not JSON. */
  private async postFile(path: string, file: { buffer: Buffer; mimetype?: string; originalname?: string }, fields: Record<string, string>): Promise<any> {
    const c = await this.creds();
    if (!c) return null;

    const form = new FormData();
    form.append(
      'file',
      new Blob([new Uint8Array(file.buffer)], { type: file.mimetype || 'image/jpeg' }),
      file.originalname || 'document.jpg',
    );
    for (const [k, v] of Object.entries(fields)) form.append(k, v);

    let res: Response;
    try {
      res = await fetch(`${c.baseUrl}${path}`, {
        method: 'POST',
        // No Content-Type here on purpose - fetch sets the multipart boundary.
        headers: { 'x-client-id': c.clientId, 'x-client-secret': c.clientSecret },
        body: form,
        signal: AbortSignal.timeout(30_000),
      });
    } catch (e: any) {
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

    // The name check is applied below, so the cache holds the raw record only.
    const key = `rc:${rc}`;
    let d = this.cached<any>(key);
    if (!d) {
      const json = await this.post('/vehicle-rc', { vehicle_number: rc });
      d = json?.data ?? json ?? {};
      this.remember(key, d);
    }
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

  /** Licence numbers are written with spaces, dashes and lowercase; strip them. */
  private normaliseDl(raw: string): string {
    return (raw || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
  }

  /**
   * Driving licence lookup against the RTO record.
   *
   * Date of birth is not optional padding - the government lookup keys on
   * licence number AND date of birth together, which is also what stops anyone
   * pulling a stranger's details from a licence number alone.
   */
  async lookupDl(dlNumber: string, dob: string): Promise<DlLookupResult> {
    const dl = this.normaliseDl(dlNumber);
    if (dl.length < 8) throw new BadRequestException('Enter a valid driving licence number');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dob || '')) {
      throw new BadRequestException("Enter the driver's date of birth");
    }

    const c = await this.creds();
    if (!c) {
      return {
        configured: false,
        found: false,
        message: 'Automatic licence lookup is not set up yet - enter the details manually.',
      };
    }

    const key = `dl:${dl}:${dob}`;
    let d = this.cached<any>(key);
    if (!d) {
      const json = await this.post('/driving-license', { dl_number: dl, dob });
      d = json?.data ?? json ?? {};
      this.remember(key, d);
    }
    const holderName = (d.name || d.holder_name || d.holderName || '').trim();
    if (!holderName) {
      return { configured: true, found: false, message: 'No record found for this licence number and date of birth' };
    }

    // The vendor returns the classes either as strings or as objects carrying a
    // code - flatten both to the codes we show.
    const rawClasses = d.vehicle_classes ?? d.cov_details ?? d.vehicleClasses ?? [];
    const vehicleClasses: string[] = Array.isArray(rawClasses)
      ? rawClasses
          .map((v: any) => (typeof v === 'string' ? v : v?.cov || v?.class || v?.category || ''))
          .map((v: string) => v.trim())
          .filter(Boolean)
      : [];

    const validUpto = d.doe || d.valid_upto || d.validUpto || d.dl_validity;
    const expiry = validUpto ? new Date(validUpto) : null;
    const expired = expiry && !Number.isNaN(expiry.getTime()) ? expiry < new Date() : undefined;

    return {
      configured: true,
      found: true,
      licence: {
        dlNumber: dl,
        holderName,
        dob: d.dob || d.date_of_birth || dob,
        gender: d.gender,
        address: (d.address || d.permanent_address || '').toString().trim() || undefined,
        issuedOn: d.doi || d.issue_date || d.issuedOn,
        validUpto,
        vehicleClasses,
        rto: (d.rto_name || d.rto || '').trim() || undefined,
        expired,
      },
      message: expired
        ? 'Licence found - but it has EXPIRED'
        : 'Licence verified',
    };
  }

  /**
   * Read an uploaded ID photo.
   *
   * `claimedName` is the name we already hold for this person (from the
   * licence), so a mismatch between the licence and the Aadhaar surfaces here
   * rather than after the driver is on a trip.
   */
  async ocrDocument(
    file: { buffer: Buffer; mimetype?: string; originalname?: string; size?: number } | undefined,
    documentType: string,
    claimedName?: string,
  ): Promise<OcrResult> {
    if (!file?.buffer?.length) throw new BadRequestException('Attach the document photo');
    // The vendor caps uploads at 5 MB; fail here rather than burning a call.
    if (file.buffer.length > 5 * 1024 * 1024) {
      throw new BadRequestException('Photo is too large - keep it under 5 MB');
    }
    const type = (documentType || 'aadhaar').toLowerCase();

    const c = await this.creds();
    if (!c) {
      return {
        configured: false,
        found: false,
        message: 'Automatic document reading is not set up yet - enter the details manually.',
      };
    }

    const json = await this.postFile('/smart-ocr', file, { document_type: type });
    const d = json?.data ?? json ?? {};
    const name = (d.name || d.full_name || '').trim();
    const uid = (d.uid || d.aadhaar_number || d.id_number || '').toString().replace(/\s/g, '');

    if (!name && !uid) {
      return {
        configured: true,
        found: false,
        message: 'Could not read this photo - try a clearer picture in good light',
      };
    }

    // Vendors spell these a few ways; treat any of them as the flag being set.
    const q = d.quality ?? d.image_quality ?? d;
    const quality = {
      blurred: Boolean(q.blur || q.is_blur || q.blurred),
      glare: Boolean(q.glare || q.is_glare),
      screenshot: Boolean(q.screenshot || q.is_screenshot || q.screen_capture),
      tampered: Boolean(q.tampered || q.is_tampered || q.tamper_detected),
    };

    const result: OcrResult = {
      configured: true,
      found: true,
      document: {
        type,
        name: name || undefined,
        dob: d.dob || d.date_of_birth,
        gender: d.gender,
        address: (d.address || '').toString().trim() || undefined,
        // Aadhaar: keep the last 4 and nothing else. Other IDs are fine in full.
        aadhaarLast4: type === 'aadhaar' && uid ? uid.slice(-4) : undefined,
        idNumber: type === 'aadhaar' ? undefined : uid || undefined,
      },
      quality,
      message: 'Document read',
    };

    // A forged or screen-captured image is worth more than a name mismatch.
    if (quality.tampered || quality.screenshot) {
      result.message = 'This looks like a photo of a screen or an edited image - upload the original document';
    } else if (quality.blurred || quality.glare) {
      result.message = 'Read, but the photo is blurred or has glare - a clearer one is safer';
    }

    if (claimedName && name) {
      result.nameMatch = matchNames(name, claimedName);
      if (!result.nameMatch.matched) {
        result.message = 'The name on this document does not match the licence';
      } else if (!quality.tampered && !quality.screenshot && !quality.blurred && !quality.glare) {
        // Say what was actually confirmed, not just that a read happened.
        result.message = 'Aadhaar read - name matches the licence';
      }
    }
    return result;
  }
}
