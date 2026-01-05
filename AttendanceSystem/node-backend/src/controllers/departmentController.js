const Department = require('../models/Department');

// Create department
exports.createDepartment = async (req, res) => {
  try {
    const { code, name, description, manager, isActive } = req.body;

    const existing = await Department.findOne({ $or: [{ code }, { name }] });
    if (existing) {
      return res.status(400).json({ success: false, message: 'Department code or name already exists' });
    }

    const department = new Department({
      code,
      name,
      description: description || '',
      manager: manager || null,
      isActive: isActive !== undefined ? isActive : true,
    });

    await department.save();
    res.status(201).json({ success: true, message: 'Department created', data: department });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Error creating department', error: error.message });
  }
};

// Get all departments
exports.getDepartments = async (_req, res) => {
  try {
    const departments = await Department.find().populate('manager', 'fullName employeeId');
    res.json({ success: true, count: departments.length, data: departments });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Error fetching departments', error: error.message });
  }
};

// Get department by id
exports.getDepartmentById = async (req, res) => {
  try {
    const department = await Department.findById(req.params.id).populate('manager', 'fullName employeeId');
    if (!department) {
      return res.status(404).json({ success: false, message: 'Department not found' });
    }
    res.json({ success: true, data: department });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Error fetching department', error: error.message });
  }
};

// Update department
exports.updateDepartment = async (req, res) => {
  try {
    const { code, name, description, manager, isActive } = req.body;

    const department = await Department.findById(req.params.id);
    if (!department) {
      return res.status(404).json({ success: false, message: 'Department not found' });
    }

    if (code && code !== department.code) {
      const exists = await Department.findOne({ code });
      if (exists) return res.status(400).json({ success: false, message: 'Department code already exists' });
      department.code = code;
    }

    if (name && name !== department.name) {
      const exists = await Department.findOne({ name });
      if (exists) return res.status(400).json({ success: false, message: 'Department name already exists' });
      department.name = name;
    }

    if (description !== undefined) department.description = description;
    if (manager !== undefined) department.manager = manager;
    if (isActive !== undefined) department.isActive = isActive;

    await department.save();
    res.json({ success: true, message: 'Department updated', data: department });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Error updating department', error: error.message });
  }
};

// Delete department
exports.deleteDepartment = async (req, res) => {
  try {
    const department = await Department.findByIdAndDelete(req.params.id);
    if (!department) {
      return res.status(404).json({ success: false, message: 'Department not found' });
    }
    res.json({ success: true, message: 'Department deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Error deleting department', error: error.message });
  }
};
