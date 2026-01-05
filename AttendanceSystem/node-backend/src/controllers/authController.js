const Employee = require('../models/Employee');
const Department = require('../models/Department');
const Device = require('../models/Device');
const User = require('../models/User');
const jwt = require('jsonwebtoken');
const QRCode = require('qrcode');

// Generate JWT token
const generateToken = (payload) => {
  return jwt.sign(
    payload,
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
};

// Register new employee
exports.register = async (req, res) => {
  try {
    const { 
      employeeId,
      fullName,
      email,
      password,
      phone,
      department,
      position,
      role,
      employmentType,
      manager,
      nfcUid
    } = req.body;

    // Validate department
    const departmentDoc = await Department.findById(department);
    if (!departmentDoc) {
      return res.status(400).json({
        success: false,
        message: 'Invalid department'
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ success: false, message: 'User with this email already exists' });
    }

    // Create User
    const user = new User({
      email,
      password,
      phone,
      role: role || 'employee',
      status: 'active'
    });
    await user.save();

    // Create Employee (link to user)
    const employee = new Employee({
      employeeId,
      fullName,
      phone,
      department,
      position,
      manager: manager || null,
      nfcUid: nfcUid || null,
      employmentType: employmentType || 'fulltime',
      user: user._id
    });

    // Generate QR code for employee
    const qrData = JSON.stringify({ employeeId: employee.employeeId, id: employee._id, v: employee.qrCodeVersion });
    const qrCodeUrl = await QRCode.toDataURL(qrData);
    employee.qrCodeDataUrl = qrCodeUrl;

    await employee.save();

    // Link back user->employee
    user.employee = employee._id;
    await user.save();

    // Generate token
    const token = generateToken({ userId: user._id, employeeId: employee._id, role: user.role });

    res.status(201).json({
      success: true,
      message: 'Employee registered successfully',
      data: {
        employee: {
          id: employee._id,
          employeeId: employee.employeeId,
          fullName: employee.fullName,
          department: employee.department,
          position: employee.position,
          role: user.role,
          qrCodeVersion: employee.qrCodeVersion,
          qrCodeDataUrl: employee.qrCodeDataUrl
        },
        token
      }
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error registering employee', 
      error: error.message 
    });
  }
};

// Login
exports.login = async (req, res) => {
  try {
    const { email, password, username } = req.body;

    // Find user by email or username
    let user;
    if (username) {
      user = await User.findOne({ username });
    } else if (email) {
      user = await User.findOne({ email });
    } else {
      return res.status(400).json({ success: false, message: 'Email or username is required' });
    }

    if (!user) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    if (user.status !== 'active') {
      return res.status(401).json({ success: false, message: 'Account is deactivated' });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    // Update last login
    user.lastLoginAt = new Date();
    await user.save();

    // Check if device user
    if (user.role === 'device') {
      const device = await Device.findOne({ user: user._id });
      const token = generateToken({ userId: user._id, deviceId: device?._id, role: user.role });
      
      return res.json({
        success: true,
        message: 'Login successful',
        data: {
          device: {
            id: device?._id,
            code: device?.code,
            name: device?.name,
            deviceType: device?.deviceType,
            status: device?.status,
            role: user.role
          },
          token
        }
      });
    }

    // Regular employee login
    const employee = await Employee.findOne({ user: user._id });

    const token = generateToken({ userId: user._id, employeeId: employee?._id, role: user.role });

    res.json({
      success: true,
      message: 'Login successful',
      data: {
        employee: {
          id: employee?._id,
          employeeId: employee?.employeeId,
          fullName: employee?.fullName,
          department: employee?.department,
          position: employee?.position,
          role: user.role,
          avatar: employee?.avatar,
          qrCodeVersion: employee?.qrCodeVersion,
          qrCodeDataUrl: employee?.qrCodeDataUrl
        },
        token
      }
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error logging in', 
      error: error.message 
    });
  }
};

// Get current user profile
exports.getProfile = async (req, res) => {
  try {
    const employee = await Employee.findById(req.user.employeeId)
      .populate('department', 'code name')
      .populate('manager', 'fullName employeeId')
      .populate('user', 'email phone role status');

    if (!employee) {
      return res.status(404).json({ 
        success: false, 
        message: 'Employee not found' 
      });
    }

    res.json({
      success: true,
      data: employee
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error getting profile', 
      error: error.message 
    });
  }
};
