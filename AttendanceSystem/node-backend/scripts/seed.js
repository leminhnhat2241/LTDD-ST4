require('dotenv').config();
const mongoose = require('mongoose');

const Department = require('../src/models/Department');
const Shift = require('../src/models/Shift');
const Device = require('../src/models/Device');
const User = require('../src/models/User');
const Role = require('../src/models/Role');

async function connectDB() {
  if (!process.env.MONGODB_URI) {
    throw new Error('Missing MONGODB_URI in .env');
  }
  await mongoose.connect(process.env.MONGODB_URI);
}

async function seedRoles() {
  const defaults = [
    { name: 'admin', description: 'Administrator with full access', permissions: ['all'] },
    { name: 'manager', description: 'Manager with department access', permissions: ['manage_department', 'view_reports'] },
    { name: 'employee', description: 'Regular employee', permissions: ['view_own_data'] },
    { name: 'device', description: 'Attendance device', permissions: ['record_attendance'] }
  ];
  for (const role of defaults) {
    await Role.updateOne({ name: role.name }, { $set: role }, { upsert: true });
  }
}

async function seedDepartments() {
  const defaults = [
    { code: 'GEN', name: 'General', description: 'Default department' },
    { code: 'HR', name: 'Human Resources' },
    { code: 'IT', name: 'Information Technology' },
  ];
  for (const dept of defaults) {
    await Department.updateOne({ code: dept.code }, { $set: dept }, { upsert: true });
  }
}

async function seedShifts() {
  const defaults = [
    {
      code: 'HC',
      name: 'Hanh Chinh',
      startTime: '08:30',
      endTime: '17:30',
      graceLateMinutes: 10,
      earlyLeaveMinutes: 10,
      daysOfWeek: [1, 2, 3, 4, 5],
      isFlexible: false,
    },
  ];
  for (const shift of defaults) {
    await Shift.updateOne({ code: shift.code }, { $set: shift }, { upsert: true });
  }
}

async function seedDevices() {
  const defaults = [
    {
      code: 'ATTN-01',
      name: 'Attendance Device 01',
      username: 'device01',
      password: 'device123',
      deviceType: 'attendance',
      status: 'active',
      location: {
        latitude: null,
        longitude: null,
        address: 'Front Desk',
      },
    },
  ];
  
  for (const deviceData of defaults) {
    const existingDevice = await Device.findOne({ code: deviceData.code });
    
    if (!existingDevice) {
      // Create user for device
      const existingUser = await User.findOne({ username: deviceData.username });
      let user;
      
      if (!existingUser) {
        user = new User({
          username: deviceData.username,
          password: deviceData.password,
          role: 'device',
          status: 'active'
        });
        await user.save();
      } else {
        user = existingUser;
      }

      // Create device
      const device = new Device({
        code: deviceData.code,
        name: deviceData.name,
        deviceType: deviceData.deviceType,
        status: deviceData.status,
        location: deviceData.location,
        user: user._id
      });
      await device.save();

      // Link back
      user.device = device._id;
      await user.save();
      
      console.log(`Created device: ${deviceData.code} with username: ${deviceData.username}`);
    }
  }
}

async function run() {
  try {
    await connectDB();
    await seedRoles();
    await seedDepartments();
    await seedShifts();
    await seedDevices();
    console.log('Seeding completed');
  } catch (err) {
    console.error('Seeding failed:', err.message);
  } finally {
    await mongoose.disconnect();
  }
}

run();
