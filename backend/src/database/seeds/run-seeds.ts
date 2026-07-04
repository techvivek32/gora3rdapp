import mongoose from 'mongoose';
import * as bcrypt from 'bcryptjs';
import * as dotenv from 'dotenv';

dotenv.config();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/goracabs';

const UserSchema = new mongoose.Schema({ email: String, mobile: String, fullName: String, password: String, role: String, membershipType: String, isVerified: Boolean, isAdminApproved: Boolean, isActive: Boolean });
const CitySchema = new mongoose.Schema({ name: String, state: String, slug: String, isActive: Boolean, isFeatured: Boolean, sortOrder: Number, requirementCount: Number, vehicleCount: Number, userCount: Number, aliases: [String] });
const SubscriptionPlanSchema = new mongoose.Schema({ name: String, description: String, membershipType: String, duration: String, price: Number, discountedPrice: Number, durationDays: Number, features: [String], isActive: Boolean, isPopular: Boolean, sortOrder: Number }, { collection: 'subscriptionPlans' });

async function runSeeds() {
  await mongoose.connect(MONGODB_URI);
  console.log('Connected to MongoDB');

  const User = mongoose.model('User', UserSchema);
  const City = mongoose.model('City', CitySchema);
  const SubscriptionPlan = mongoose.model('SubscriptionPlan', SubscriptionPlanSchema);

  // Seed admin user
  const existingAdmin = await User.findOne({ email: process.env.ADMIN_EMAIL || 'admin@goracabs.com' });
  if (!existingAdmin) {
    const hashedPwd = await bcrypt.hash(process.env.ADMIN_PASSWORD || 'Admin@1234', 12);
    await User.create({
      fullName: 'Super Admin',
      email: process.env.ADMIN_EMAIL || 'admin@goracabs.com',
      mobile: '9000000000',
      password: hashedPwd,
      role: 'super_admin',
      membershipType: 'golden',
      isVerified: true,
      isAdminApproved: true,
      isActive: true,
    });
    console.log('Admin user created');
  } else {
    console.log('Admin user already exists');
  }

  // Seed cities
  const citiesCount = await City.countDocuments();
  if (citiesCount === 0) {
    const cities = [
      { name: 'Mumbai', state: 'Maharashtra', slug: 'mumbai', isActive: true, isFeatured: true, sortOrder: 1, requirementCount: 0, vehicleCount: 0, userCount: 0, aliases: ['Bombay', 'BOM'] },
      { name: 'Delhi', state: 'Delhi', slug: 'delhi', isActive: true, isFeatured: true, sortOrder: 2, requirementCount: 0, vehicleCount: 0, userCount: 0, aliases: ['New Delhi', 'DEL'] },
      { name: 'Bangalore', state: 'Karnataka', slug: 'bangalore', isActive: true, isFeatured: true, sortOrder: 3, requirementCount: 0, vehicleCount: 0, userCount: 0, aliases: ['Bengaluru', 'BLR'] },
      { name: 'Chennai', state: 'Tamil Nadu', slug: 'chennai', isActive: true, isFeatured: true, sortOrder: 4, requirementCount: 0, vehicleCount: 0, userCount: 0, aliases: ['Madras', 'MAA'] },
      { name: 'Hyderabad', state: 'Telangana', slug: 'hyderabad', isActive: true, isFeatured: true, sortOrder: 5, requirementCount: 0, vehicleCount: 0, userCount: 0, aliases: ['Hyd', 'HYD'] },
      { name: 'Pune', state: 'Maharashtra', slug: 'pune', isActive: true, isFeatured: true, sortOrder: 6, requirementCount: 0, vehicleCount: 0, userCount: 0, aliases: ['PNQ'] },
      { name: 'Ahmedabad', state: 'Gujarat', slug: 'ahmedabad', isActive: true, isFeatured: false, sortOrder: 7, requirementCount: 0, vehicleCount: 0, userCount: 0, aliases: ['AMD'] },
      { name: 'Kolkata', state: 'West Bengal', slug: 'kolkata', isActive: true, isFeatured: false, sortOrder: 8, requirementCount: 0, vehicleCount: 0, userCount: 0, aliases: ['Calcutta', 'CCU'] },
      { name: 'Jaipur', state: 'Rajasthan', slug: 'jaipur', isActive: true, isFeatured: false, sortOrder: 9, requirementCount: 0, vehicleCount: 0, userCount: 0, aliases: ['Pink City', 'JAI'] },
      { name: 'Surat', state: 'Gujarat', slug: 'surat', isActive: true, isFeatured: false, sortOrder: 10, requirementCount: 0, vehicleCount: 0, userCount: 0, aliases: ['STV'] },
    ];
    await City.insertMany(cities);
    console.log(`${cities.length} cities seeded`);
  } else {
    console.log('Cities already seeded');
  }

  // Seed subscription plans — every tier offers 1 / 3 / 6-month durations.
  // Prices are stored in paise (₹ × 100). This block always re-seeds so pricing
  // changes here are applied on `npm run seed`.
  const activeFeatures = ['Basic Features', 'View 10 contact details/month', 'Business cities filtering', 'Post unlimited requirements', 'Post up to 5 vehicles/month'];
  const premiumFeatures = ['All Premium Features', 'Unlimited contact views', 'Gold badge + Featured listings', 'Unlimited requirements & vehicles', 'Priority notifications', 'Chat access'];
  const goldenFeatures = ['All Golden Features', 'Unlimited everything', 'Golden crown badge', 'Featured listing priority #1', 'Dedicated support', 'City management for your fleet'];

  // [membershipType, durationDays, durationKey, price(₹), features, sortOrder, isPopular]
  const planMatrix: Array<[string, number, string, number, string[], number, boolean]> = [
    ['active', 30, '1_month', 99, activeFeatures, 1, false],
    ['active', 90, '3_months', 249, activeFeatures, 2, false],
    ['active', 180, '6_months', 449, activeFeatures, 3, false],
    ['premium', 30, '1_month', 199, premiumFeatures, 4, true],
    ['premium', 90, '3_months', 499, premiumFeatures, 5, true],
    ['premium', 180, '6_months', 899, premiumFeatures, 6, true],
    ['golden', 30, '1_month', 299, goldenFeatures, 7, false],
    ['golden', 90, '3_months', 699, goldenFeatures, 8, false],
    ['golden', 180, '6_months', 1199, goldenFeatures, 9, false],
  ];
  const durationName: Record<string, string> = { '1_month': '1 Month', '3_months': '3 Months', '6_months': '6 Months' };
  const tierName: Record<string, string> = { active: 'Active', premium: 'Premium', golden: 'Golden' };
  const plans = planMatrix.map(([type, days, key, rupees, features, sortOrder, isPopular]) => ({
    name: `${tierName[type]} ${durationName[key]}`,
    description: `${tierName[type]} membership for ${durationName[key].toLowerCase()}`,
    membershipType: type,
    duration: key,
    price: rupees * 100, // paise
    discountedPrice: 0,
    durationDays: days,
    features,
    isActive: true,
    isPopular,
    sortOrder,
  }));
  await SubscriptionPlan.deleteMany({});
  await SubscriptionPlan.insertMany(plans);
  console.log(`${plans.length} subscription plans seeded`);

  await mongoose.disconnect();
  console.log('Seeding complete!');
}

runSeeds().catch((e) => { console.error(e); process.exit(1); });
