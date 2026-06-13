import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { City, CityDocument } from '../../database/schemas/city.schema';

@Injectable()
export class CitiesService {
  constructor(@InjectModel(City.name) private cityModel: Model<CityDocument>) {}

  async getAll(search?: string, state?: string) {
    const filter: any = { isActive: true };
    if (search) filter.$or = [{ name: new RegExp(search, 'i') }, { state: new RegExp(search, 'i') }];
    if (state) filter.state = new RegExp(state, 'i');

    const cities = await this.cityModel.find(filter).sort({ sortOrder: 1, name: 1 }).lean();
    return { message: 'Cities retrieved', data: cities };
  }

  async getFeatured() {
    const cities = await this.cityModel.find({ isActive: true, isFeatured: true }).sort({ sortOrder: 1 }).lean();
    return { message: 'Featured cities', data: cities };
  }

  async getByState() {
    const cities = await this.cityModel.aggregate([
      { $match: { isActive: true } },
      { $group: { _id: '$state', cities: { $push: { _id: '$_id', name: '$name', slug: '$slug', imageUrl: '$imageUrl' } } } },
      { $sort: { _id: 1 } },
    ]);
    return { message: 'Cities by state', data: cities };
  }
}
