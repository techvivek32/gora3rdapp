import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import * as bcrypt from 'bcryptjs';
import { Franchise, FranchiseDocument } from '../../database/schemas/franchise.schema';

// Fields the admin form may send. Password handled separately (hashed).
const ASSIGNABLE = [
  'name', 'dob', 'city', 'state', 'email', 'phone', 'agencyName',
  'commissionPercent', 'documents', 'payoutAccounts', 'isActive',
];

@Injectable()
export class FranchiseService {
  constructor(
    @InjectModel(Franchise.name) private franchiseModel: Model<FranchiseDocument>,
  ) {}

  async list(query: any) {
    const filter: any = {};
    const search = (query?.search || '').trim();
    if (search) {
      const rx = new RegExp(search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
      filter.$or = [{ name: rx }, { phone: rx }, { email: rx }, { agencyName: rx }, { city: rx }];
    }
    // Password is select:false, so it's never returned here.
    const franchises = await this.franchiseModel.find(filter).sort({ createdAt: -1 }).lean();
    return { message: 'Franchises', data: franchises };
  }

  async getOne(id: string) {
    const franchise = await this.franchiseModel.findById(id).lean();
    if (!franchise) throw new NotFoundException('Franchise not found');
    return { message: 'Franchise', data: franchise };
  }

  async create(data: any) {
    if (!`${data.name || ''}`.trim()) throw new BadRequestException('Name is required');
    if (!`${data.phone || ''}`.trim()) throw new BadRequestException('Phone is required');
    if (!`${data.password || ''}`.trim()) throw new BadRequestException('Password is required');

    await this.ensureUnique(data.email, data.phone);

    const doc: any = this.pick(data);
    doc.password = await bcrypt.hash(`${data.password}`, 12);

    const franchise = await this.franchiseModel.create(doc);
    return { message: 'Franchise created', data: this.strip(franchise.toObject()) };
  }

  async update(id: string, data: any) {
    const existing = await this.franchiseModel.findById(id);
    if (!existing) throw new NotFoundException('Franchise not found');

    if (data.email !== undefined || data.phone !== undefined) {
      await this.ensureUnique(data.email ?? existing.email, data.phone ?? existing.phone, id);
    }

    const update: any = this.pick(data);
    // Only re-hash when a new non-empty password is provided.
    if (`${data.password || ''}`.trim()) {
      update.password = await bcrypt.hash(`${data.password}`, 12);
    }

    const franchise = await this.franchiseModel.findByIdAndUpdate(id, update, { new: true }).lean();
    return { message: 'Franchise updated', data: this.strip(franchise) };
  }

  async remove(id: string) {
    const franchise = await this.franchiseModel.findByIdAndDelete(id);
    if (!franchise) throw new NotFoundException('Franchise not found');
    return { message: 'Franchise removed' };
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  private pick(data: any) {
    const out: any = {};
    for (const k of ASSIGNABLE) {
      if (data[k] === undefined) continue;
      if (k === 'commissionPercent') {
        out[k] = Math.max(0, Math.min(100, Number(data[k]) || 0));
      } else if (k === 'email') {
        out[k] = `${data[k]}`.trim().toLowerCase();
      } else {
        out[k] = data[k];
      }
    }
    return out;
  }

  private strip(f: any) {
    if (f && f.password) delete f.password;
    return f;
  }

  private async ensureUnique(email: string | undefined, phone: string, excludeId?: string) {
    const or: any[] = [];
    if (email) or.push({ email: `${email}`.trim().toLowerCase() });
    if (phone) or.push({ phone: `${phone}`.trim() });
    if (or.length === 0) return;
    const clash = await this.franchiseModel.findOne({
      $or: or,
      ...(excludeId ? { _id: { $ne: excludeId } } : {}),
    });
    if (clash) {
      if (email && clash.email === `${email}`.trim().toLowerCase()) {
        throw new BadRequestException('Another franchise already has this email');
      }
      throw new BadRequestException('Another franchise already has this phone');
    }
  }
}
