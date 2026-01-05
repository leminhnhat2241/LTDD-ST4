const Employee = require('../models/Employee');
const Department = require('../models/Department');
const User = require('../models/User');
const QRCode = require('qrcode');
const Counter = require('../models/Counter');

async function generateEmployeeId() {
  const result = await Counter.findOneAndUpdate(
    { key: 'employeeId' },
    { $inc: { seq: 1 } },
    { new: true, upsert: true }
  );
  const seq = result.seq || 1;
  return `EMP${String(seq).padStart(3, '0')}`;
}

// Admin: create employee (can be manager/employee)
exports.createEmployee = async (req, res) => {
  try {
    const {
      fullName,
      email,
      password,
      phone,
      department,
      position,
      role,
      nfcUid,
      manager,
      employmentType,
    } = req.body;

    const departmentDoc = await Department.findById(department);
    if (!departmentDoc) {
      return res.status(400).json({ success: false, message: 'Invalid department' });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ success: false, message: 'User already exists (email)' });
    }

    const nextEmployeeId = await generateEmployeeId();

    // Create user first
    const user = new User({
      email,
      password,
      phone,
      role: role || 'employee',
      status: 'active'
    });
    await user.save();

    const employee = new Employee({
      employeeId: nextEmployeeId,
      fullName,
      phone,
      department,
      position,
      nfcUid: nfcUid || null,
      manager: manager || null,
      employmentType: employmentType || 'fulltime',
      user: user._id,
    });

    // Generate QR code (versioned)
    const qrData = JSON.stringify({ employeeId: employee.employeeId, id: employee._id, v: employee.qrCodeVersion });
    const qrCodeUrl = await QRCode.toDataURL(qrData);
    employee.qrCodeDataUrl = qrCodeUrl;

    await employee.save();

    user.employee = employee._id;
    await user.save();

    const safeEmployee = employee.toObject();
    const safeUser = user.toObject();
    delete safeUser.password;

    res.status(201).json({
      success: true,
      message: 'Employee created',
      data: { employee: safeEmployee, user: safeUser },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Error creating employee', error: error.message });
  }
};

// Get all employees
exports.getAllEmployees = async (req, res) => {
  try {
    const employees = await Employee.find()
      .populate('department', 'code name')
      .populate('manager', 'fullName employeeId')
      .populate('user', 'email phone role status');
    
    res.json({
      success: true,
      count: employees.length,
      data: employees
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching employees', 
      error: error.message 
    });
  }
};

// Get employee by ID
exports.getEmployeeById = async (req, res) => {
  try {
    const employee = await Employee.findById(req.params.id)
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
      message: 'Error fetching employee', 
      error: error.message 
    });
  }
};

// Update employee
exports.updateEmployee = async (req, res) => {
  try {
    const { 
      fullName,
      email,
      phone,
      department,
      position,
      role,
      nfcUid,
      status,
      manager,
      employmentType
    } = req.body;

    const employee = await Employee.findById(req.params.id);

    if (!employee) {
      return res.status(404).json({ 
        success: false, 
        message: 'Employee not found' 
      });
    }

    const user = await User.findById(employee.user);

    // Update fields
    if (fullName) employee.fullName = fullName;
    if (phone) employee.phone = phone;
    if (department) {
      const departmentDoc = await Department.findById(department);
      if (!departmentDoc) {
        return res.status(400).json({ success: false, message: 'Invalid department' });
      }
      employee.department = department;
    }
    if (position) employee.position = position;
    if (nfcUid !== undefined) employee.nfcUid = nfcUid;
    if (manager !== undefined) employee.manager = manager;
    if (employmentType !== undefined) employee.employmentType = employmentType;

    if (email) user.email = email;
    if (phone) user.phone = phone;
    if (role) user.role = role;
    if (status !== undefined) user.status = status;

    await employee.save();
    if (user) await user.save();

    res.json({
      success: true,
      message: 'Employee updated successfully',
      data: { employee, user }
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error updating employee', 
      error: error.message 
    });
  }
};

// Delete employee
exports.deleteEmployee = async (req, res) => {
  try {
    const employee = await Employee.findByIdAndDelete(req.params.id);

    if (!employee) {
      return res.status(404).json({ 
        success: false, 
        message: 'Employee not found' 
      });
    }

    // Clean up user
    if (employee.user) {
      await User.findByIdAndDelete(employee.user);
    }

    res.json({
      success: true,
      message: 'Employee deleted successfully'
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error deleting employee', 
      error: error.message 
    });
  }
};

// Regenerate QR code
exports.regenerateQRCode = async (req, res) => {
  try {
    const employee = await Employee.findById(req.params.id);

    if (!employee) {
      return res.status(404).json({ 
        success: false, 
        message: 'Employee not found' 
      });
    }

    employee.qrCodeVersion += 1;
    const qrData = JSON.stringify({ 
      employeeId: employee.employeeId, 
      id: employee._id,
      v: employee.qrCodeVersion
    });
    const qrCodeUrl = await QRCode.toDataURL(qrData);
    employee.qrCodeDataUrl = qrCodeUrl;

    await employee.save();

    res.json({
      success: true,
      message: 'QR code regenerated successfully',
      data: {
        qrCodeVersion: employee.qrCodeVersion,
        qrCodeDataUrl: employee.qrCodeDataUrl
      }
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error regenerating QR code', 
      error: error.message 
    });
  }
};
