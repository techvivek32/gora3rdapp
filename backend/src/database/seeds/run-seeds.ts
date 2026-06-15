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

  // Seed subscription plans
  const plansCount = await SubscriptionPlan.countDocuments();
  if (plansCount === 0) {
    const plans = [
      {
        name: 'Active Monthly',
        description: 'Get access to business cities filtering and network features',
        membershipType: 'active',
        duration: 'monthly',
        price: 49900,
        discountedPrice: 29900,
        durationDays: 30,
        features: ['View 10 contact details/month', 'Business cities filtering', 'Post unlimited requirements', 'Post up to 5 vehicles/month'],
        isActive: true,
        isPopular: false,
        sortOrder: 1,
      },
      {
        name: 'Verified Monthly',
        description: 'Verified badge + expanded contact access',
        membershipType: 'verified',
        duration: 'monthly',
        price: 99900,
        discountedPrice: 79900,
        durationDays: 30,
        features: ['View 50 contact details/month', 'Verified badge on profile', 'Business cities filtering', 'Post unlimited requirements', 'Post unlimited vehicles', 'Priority listing'],
        isActive: true,
        isPopular: false,
        sortOrder: 2,
      },
      {
        name: 'Premium Monthly',
        description: 'Full contact access and featured listings',
        membershipType: 'premium',
        duration: 'monthly',
        price: 199900,
        discountedPrice: 149900,
        durationDays: 30,
        features: ['Unlimited contact views', 'Gold badge + Featured listings', 'Business cities filtering', 'Unlimited requirements & vehicles', 'Priority notifications', 'Chat access'],
        isActive: true,
        isPopular: true,
        sortOrder: 3,
      },
      {
        name: 'Golden Annual',
        description: 'Top-tier membership with all premium benefits for a full year',
        membershipType: 'golden',
        duration: 'yearly',
        price: 1999900,
        discountedPrice: 1499900,
        durationDays: 365,
        features: ['Unlimited everything', 'Golden crown badge', 'Featured listing priority #1', 'Dedicated support', 'Early access to new features', 'City management for your fleet'],
        isActive: true,
        isPopular: false,
        sortOrder: 4,
      },
    ];
    await SubscriptionPlan.insertMany(plans);
    console.log(`${plans.length} subscription plans seeded`);
  } else {
    console.log('Subscription plans already seeded');
  }

  await mongoose.disconnect();
  console.log('Seeding complete!');
}

runSeeds().catch((e) => { console.error(e); process.exit(1); });
