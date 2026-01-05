const Device = require('../models/Device');
const User = require('../models/User');
const Counter = require('../models/Counter');

async function generateDeviceCode() {
  const result = await Counter.findOneAndUpdate(
    { key: 'deviceCode' },
    { $inc: { seq: 1 } },
    { new: true, upsert: true }
  );
  const seq = result.seq || 1;
  return `TB${String(seq).padStart(3, '0')}`;
}

// Create device with user account
exports.createDevice = async (req, res) => {
  try {
    const { name, deviceType, status, location, username, password, email } = req.body;

    const normalizedUsername = username?.trim();

    // Validate required fields
    if (!normalizedUsername || !password) {
      return res.status(400).json({
        success: false,
        message: 'Username and password are required for device'
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters'
      });
    }

    const deviceEmail = (email && email.trim().length > 0)
      ? email.trim().toLowerCase()
      : `${normalizedUsername.toLowerCase()}@device.local`;

    const finalCode = await generateDeviceCode();

    const existingDevice = await Device.findOne({ code: finalCode });
    if (existingDevice) {
      return res.status(400).json({ success: false, message: 'Device code already exists' });
    }

    const existingUser = await User.findOne({ $or: [{ username: normalizedUsername }, { email: deviceEmail }] });
    if (existingUser) {
      return res.status(400).json({ success: false, message: 'Username or email already exists' });
    }

    // Create User account for device
    const user = new User({
      username: normalizedUsername,
      email: deviceEmail,
      password,
      role: 'device',
      status: 'active'
    });
    await user.save();

    // Create Device
    const device = new Device({
      code: finalCode,
      name,
      deviceType: deviceType || 'attendance',
      status: status || 'active',
      location: location || {},
      user: user._id
    });

    await device.save();

    // Link back user->device
    user.device = device._id;
    await user.save();

    res.status(201).json({ 
      success: true, 
      message: 'Device created with user account', 
      data: {
        device: {
          id: device._id,
          code: device.code,
          name: device.name,
          deviceType: device.deviceType,
          status: device.status,
          location: device.location
        },
        user: {
          username: user.username,
          role: user.role
        }
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Error creating device', error: error.message });
  }
};

// Get all devices
exports.getDevices = async (_req, res) => {
  try {
    const devices = await Device.find().populate('user', 'username role status');
    res.json({ success: true, count: devices.length, data: devices });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Error fetching devices', error: error.message });
  }
};

// Get device by id
exports.getDeviceById = async (req, res) => {
  try {
    const device = await Device.findById(req.params.id).populate('user', 'username role status');
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not found' });
    }
    res.json({ success: true, data: device });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Error fetching device', error: error.message });
  }
};

// Update device
exports.updateDevice = async (req, res) => {
  try {
    const { name, deviceType, status, location, password } = req.body;

    const device = await Device.findById(req.params.id);
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not found' });
    }

    if (name !== undefined) device.name = name;
    if (deviceType !== undefined) device.deviceType = deviceType;
    if (status !== undefined) device.status = status;
    if (location !== undefined) device.location = location;

    // Update password if provided
    if (password) {
      if (password.length < 6) {
        return res.status(400).json({ 
          success: false, 
          message: 'Password must be at least 6 characters' 
        });
      }
      const user = await User.findById(device.user);
      if (user) {
        user.password = password;
        await user.save();
      }
    }

    await device.save();
    res.json({ success: true, message: 'Device updated', data: device });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Error updating device', error: error.message });
  }
};

// Delete device
exports.deleteDevice = async (req, res) => {
  try {
    const device = await Device.findById(req.params.id);
    if (!device) {
      return res.status(404).json({ success: false, message: 'Device not found' });
    }

    // Delete associated user account
    if (device.user) {
      await User.findByIdAndDelete(device.user);
    }

    await Device.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Device and associated user account deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Error deleting device', error: error.message });
  }
};
