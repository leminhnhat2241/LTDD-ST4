const Attendance = require('../models/Attendance');
const Employee = require('../models/Employee');
const Device = require('../models/Device');
const Shift = require('../models/Shift');
const ExcelJS = require('exceljs');

// Helper: convert current time to Vietnam date string (UTC+7)
const toVnDate = (date = new Date()) => {
  const vn = new Date(date.getTime() + 7 * 60 * 60 * 1000);
  return vn.toISOString().split('T')[0];
};

// Helper: convert Date to ISO string at UTC+7
const toVnDateTimeIso = (date) => {
  if (!date) return null;
  const vn = new Date(date.getTime() + 7 * 60 * 60 * 1000);
  return vn.toISOString();
};

// Helper: attach local time fields for responses
const toVnAttendance = (attendanceDoc) => {
  if (!attendanceDoc) return null;
  const obj = attendanceDoc.toObject ? attendanceDoc.toObject() : { ...attendanceDoc };
  obj.checkInTimeLocal = toVnDateTimeIso(attendanceDoc.checkInTime);
  obj.checkOutTimeLocal = toVnDateTimeIso(attendanceDoc.checkOutTime);
  return obj;
};

// Simple CSV builder for report export
const buildReportCsv = (rows) => {
  const headers = [
    'employeeId',
    'fullName',
    'departmentCode',
    'departmentName',
    'totalRecords',
    'checkIns',
    'checkOuts',
    'totalWorkMinutes',
    'lateCount',
    'earlyLeaveCount',
    'onTimeCount',
    'manualCount'
  ];

  const escape = (val) => {
    if (val === null || val === undefined) return '';
    const str = String(val);
    return /[",\n]/.test(str) ? `"${str.replace(/"/g, '""')}"` : str;
  };

  const lines = [headers.join(',')];

  for (const row of rows) {
    const dept = row.department || {};
    const values = [
      row.employeeId,
      row.fullName,
      dept.code,
      dept.name,
      row.totalRecords,
      row.checkIns,
      row.checkOuts,
      row.totalWorkMinutes,
      row.lateCount,
      row.earlyLeaveCount,
      row.onTimeCount,
      row.manualCount
    ];
    lines.push(values.map(escape).join(','));
  }

  return lines.join('\n');
};

// Build Excel buffer for report export
const buildReportExcel = async (rows) => {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Attendance Report');

  sheet.columns = [
    { header: 'Employee ID', key: 'employeeId', width: 15 },
    { header: 'Full Name', key: 'fullName', width: 25 },
    { header: 'Dept Code', key: 'departmentCode', width: 12 },
    { header: 'Dept Name', key: 'departmentName', width: 20 },
    { header: 'Total Records', key: 'totalRecords', width: 15 },
    { header: 'Check-ins', key: 'checkIns', width: 12 },
    { header: 'Check-outs', key: 'checkOuts', width: 12 },
    { header: 'Total Work Minutes', key: 'totalWorkMinutes', width: 18 },
    { header: 'Late', key: 'lateCount', width: 8 },
    { header: 'Early Leave', key: 'earlyLeaveCount', width: 12 },
    { header: 'On Time', key: 'onTimeCount', width: 10 },
    { header: 'Manual Count', key: 'manualCount', width: 14 },
  ];

  for (const row of rows) {
    const dept = row.department || {};
    sheet.addRow({
      employeeId: row.employeeId,
      fullName: row.fullName,
      departmentCode: dept.code,
      departmentName: dept.name,
      totalRecords: row.totalRecords,
      checkIns: row.checkIns,
      checkOuts: row.checkOuts,
      totalWorkMinutes: row.totalWorkMinutes,
      lateCount: row.lateCount,
      earlyLeaveCount: row.earlyLeaveCount,
      onTimeCount: row.onTimeCount,
      manualCount: row.manualCount,
    });
  }

  // Simple header bold styling
  sheet.getRow(1).font = { bold: true };

  return workbook.xlsx.writeBuffer();
};

// List supported attendance methods and auth requirements
exports.getMethods = (_req, res) => {
  res.json({
    success: true,
    data: [
      { method: 'qr', requiresAuth: false, description: 'Quet ma QR (kiosk/public)' },
      { method: 'nfc', requiresAuth: false, description: 'Quet the NFC (kiosk/public)' },
      { method: 'fingerprint', requiresAuth: false, description: 'Cham cong van tay (kiosk/public)' },
      { method: 'employee_id', requiresAuth: true, description: 'Nhap ma nhan vien thu cong (admin/manager)' },
      { method: 'manual', requiresAuth: true, description: 'Ghi nhan thu cong co ly do (admin/manager)' }
    ]
  });
};

// Report for managers/admins
exports.getReport = async (req, res) => {
  try {
    const { startDate, endDate, departmentId, employeeId, method, format } = req.query;

    const match = {};
    if (startDate && endDate) {
      match.date = { $gte: startDate, $lte: endDate };
    }
    if (departmentId) {
      match.department = departmentId;
    }
    if (employeeId) {
      match.employeeId = employeeId;
    }
    if (method) {
      match.$or = [
        { checkInMethod: method },
        { checkOutMethod: method }
      ];
    }

    const report = await Attendance.aggregate([
      { $match: match },
      {
        $lookup: {
          from: 'employees',
          localField: 'employee',
          foreignField: '_id',
          as: 'employeeDoc'
        }
      },
      { $unwind: '$employeeDoc' },
      {
        $lookup: {
          from: 'departments',
          localField: 'department',
          foreignField: '_id',
          as: 'deptDoc'
        }
      },
      { $unwind: { path: '$deptDoc', preserveNullAndEmptyArrays: true } },
      {
        $group: {
          _id: '$employee',
          employeeId: { $first: '$employeeId' },
          fullName: { $first: '$employeeDoc.fullName' },
          department: {
            $first: {
              id: '$deptDoc._id',
              code: '$deptDoc.code',
              name: '$deptDoc.name'
            }
          },
          totalRecords: { $sum: 1 },
          checkIns: { $sum: { $cond: [{ $ifNull: ['$checkInTime', false] }, 1, 0] } },
          checkOuts: { $sum: { $cond: [{ $ifNull: ['$checkOutTime', false] }, 1, 0] } },
          totalWorkMinutes: { $sum: { $ifNull: ['$workDuration', 0] } },
          lateCount: { $sum: { $cond: [{ $eq: ['$status', 'late'] }, 1, 0] } },
          earlyLeaveCount: { $sum: { $cond: [{ $eq: ['$status', 'early-leave'] }, 1, 0] } },
          onTimeCount: { $sum: { $cond: [{ $eq: ['$status', 'on-time'] }, 1, 0] } },
          manualCount: {
            $sum: {
              $cond: [
                {
                  $or: [
                    { $in: ['$checkInMethod', ['manual', 'employee_id']] },
                    { $in: ['$checkOutMethod', ['manual', 'employee_id']] },
                    { $eq: ['$fallbackUsed', true] }
                  ]
                },
                1,
                0
              ]
            }
          }
        }
      },
      { $sort: { employeeId: 1 } }
    ]);

    const outFormat = (format || 'json').toLowerCase();

    if (outFormat === 'csv') {
      const csv = buildReportCsv(report);
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename="attendance-report.csv"');
      return res.send(csv);
    }

    if (outFormat === 'excel' || outFormat === 'xlsx') {
      const buffer = await buildReportExcel(report);
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', 'attachment; filename="attendance-report.xlsx"');
      return res.send(buffer);
    }

    // Default JSON
    res.json({ success: true, count: report.length, data: report });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Error building report', error: error.message });
  }
};

// Check in
exports.checkIn = async (req, res) => {
  try {
    const { employeeId, method, location, nfcUid, deviceCode, shiftCode, fallbackReason, fingerprintId, photoBase64 } = req.body;

    const allowedMethods = ['nfc', 'qr', 'manual', 'employee_id', 'fingerprint'];
    if (!allowedMethods.includes(method)) {
      return res.status(400).json({ success: false, message: 'Invalid method' });
    }

    let employee;

    if (method === 'nfc' && nfcUid) {
      employee = await Employee.findOne({ nfcUid }).populate('user', 'status');
    } else if (employeeId) {
      employee = await Employee.findOne({ employeeId }).populate('user', 'status');
    }

    if (!employee || !employee.user || employee.user.status !== 'active') {
      return res.status(404).json({ success: false, message: 'Employee not found or inactive' });
    }

    // Resolve shift if provided
    let shift = null;
    if (shiftCode) {
      shift = await Shift.findOne({ code: shiftCode, isActive: true });
      if (!shift) {
        return res.status(400).json({ success: false, message: 'Invalid shift code' });
      }
    }

    // Resolve device if provided
    let device = null;
    if (deviceCode) {
      device = await Device.findOne({ code: deviceCode, status: 'active' });
      if (!device) {
        return res.status(400).json({ success: false, message: 'Invalid or inactive device' });
      }
    }

    // Check if already checked in today
    const today = toVnDate();
    const existingAttendance = await Attendance.findOne({
      employee: employee._id,
      date: today
    });

    if (existingAttendance && existingAttendance.checkInTime) {
      return res.status(400).json({ 
        success: false, 
        message: 'Hôm nay đã check-in rồi' 
      });
    }

    const checkInTime = new Date();
    const checkInMetadata = {};

    if (method === 'fingerprint') {
      if (!fingerprintId) {
        return res.status(400).json({ success: false, message: 'fingerprintId is required for fingerprint method' });
      }
      checkInMetadata.fingerprintId = fingerprintId;
    }

    // Create or update attendance record
    const attendance = existingAttendance || new Attendance({
      employee: employee._id,
      employeeId: employee.employeeId,
      department: employee.department,
      date: today
    });

    attendance.shift = shift ? shift._id : attendance.shift;
    attendance.device = device ? device._id : attendance.device;
    attendance.checkInTime = checkInTime;
    attendance.checkInMethod = method;
    attendance.checkInMetadata = Object.keys(checkInMetadata).length ? checkInMetadata : attendance.checkInMetadata;
    if (photoBase64) {
      attendance.checkInPhoto = photoBase64;
    }
    attendance.checkInLocation = location;
    attendance.fallbackUsed = method === 'manual' || method === 'employee_id' || !!fallbackReason;
    attendance.fallbackReason = fallbackReason || attendance.fallbackReason;

    await attendance.save();

    // Update employee last check-in
    employee.lastCheckInAt = checkInTime;
    await employee.save();

    res.status(201).json({
      success: true,
      message: 'Check-in successful',
      data: toVnAttendance(attendance)
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error checking in', 
      error: error.message 
    });
  }
};

// Check out
exports.checkOut = async (req, res) => {
  try {
    const { employeeId, method, location, nfcUid, deviceCode, shiftCode, fallbackReason, fingerprintId, photoBase64 } = req.body;

    const allowedMethods = ['nfc', 'qr', 'manual', 'employee_id', 'fingerprint'];
    if (!allowedMethods.includes(method)) {
      return res.status(400).json({ success: false, message: 'Invalid method' });
    }

    let employee;

    if (method === 'nfc' && nfcUid) {
      employee = await Employee.findOne({ nfcUid }).populate('user', 'status');
    } else if (employeeId) {
      employee = await Employee.findOne({ employeeId }).populate('user', 'status');
    }

    if (!employee || !employee.user || employee.user.status !== 'active') {
      return res.status(404).json({ success: false, message: 'Employee not found or inactive' });
    }

    let shift = null;
    if (shiftCode) {
      shift = await Shift.findOne({ code: shiftCode, isActive: true });
      if (!shift) {
        return res.status(400).json({ success: false, message: 'Invalid shift code' });
      }
    }

    let device = null;
    if (deviceCode) {
      device = await Device.findOne({ code: deviceCode, status: 'active' });
      if (!device) {
        return res.status(400).json({ success: false, message: 'Invalid or inactive device' });
      }
    }

    const today = toVnDate();
    const attendance = await Attendance.findOne({
      employee: employee._id,
      date: today
    });

    if (!attendance || !attendance.checkInTime) {
      return res.status(404).json({ 
        success: false, 
        message: 'Chưa có check-in hôm nay' 
      });
    }

    if (attendance.checkOutTime) {
      return res.status(400).json({ success: false, message: 'Hôm nay đã check-out rồi' });
    }

    const checkOutTime = new Date();

    attendance.checkOutTime = checkOutTime;
    const checkOutMetadata = {};
    if (method === 'fingerprint') {
      if (!fingerprintId) {
        return res.status(400).json({ success: false, message: 'fingerprintId is required for fingerprint method' });
      }
      checkOutMetadata.fingerprintId = fingerprintId;
    }

    attendance.checkOutMethod = method;
    attendance.checkOutMetadata = Object.keys(checkOutMetadata).length ? checkOutMetadata : attendance.checkOutMetadata;
    if (photoBase64) {
      attendance.checkOutPhoto = photoBase64;
    }
    attendance.checkOutLocation = location;
    attendance.device = device ? device._id : attendance.device;
    attendance.shift = shift ? shift._id : attendance.shift;
    attendance.fallbackUsed = attendance.fallbackUsed || method === 'manual' || method === 'employee_id' || !!fallbackReason;
    attendance.fallbackReason = fallbackReason || attendance.fallbackReason;

    await attendance.save();

    // Update employee last check-out
    employee.lastCheckOutAt = checkOutTime;
    await employee.save();

    res.json({
      success: true,
      message: 'Check-out successful',
      data: toVnAttendance(attendance)
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error checking out', 
      error: error.message 
    });
  }
};

// Get attendance records
exports.getAttendanceRecords = async (req, res) => {
  try {
    const { startDate, endDate, employeeId, departmentId, shiftCode, method } = req.query;

    let query = {};

    if (startDate && endDate) {
      query.date = { $gte: startDate, $lte: endDate };
    }

    if (employeeId) {
      const employee = await Employee.findOne({ employeeId });
      if (employee) {
        query.employee = employee._id;
      }
    }

    if (departmentId) {
      query.department = departmentId;
    }

    if (shiftCode) {
      const shift = await Shift.findOne({ code: shiftCode });
      if (shift) {
        query.shift = shift._id;
      }
    }

    if (method) {
      query.$or = [
        { checkInMethod: method },
        { checkOutMethod: method }
      ];
    }

    const attendances = await Attendance.find(query)
      .populate('employee', '-password')
      .populate('department', 'code name')
      .populate('shift', 'code name startTime endTime')
      .populate('device', 'code name')
      .sort({ checkInTime: -1 });

    res.json({
      success: true,
      count: attendances.length,
      data: attendances.map(toVnAttendance)
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching attendance records', 
      error: error.message 
    });
  }
};

// Delete attendance record
exports.deleteAttendance = async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await Attendance.findByIdAndDelete(id);
    if (!deleted) {
      return res.status(404).json({ success: false, message: 'Attendance record not found' });
    }
    res.json({ success: true, message: 'Attendance record deleted' });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error deleting attendance record',
      error: error.message,
    });
  }
};

// Clear check-in or check-out only
exports.clearAttendanceField = async (req, res) => {
  try {
    const { id } = req.params;
    const field = (req.query.field || '').toLowerCase(); // 'checkin' | 'checkout'

    if (!['checkin', 'checkout'].includes(field)) {
      return res.status(400).json({ success: false, message: 'field must be checkin or checkout' });
    }

    const attendance = await Attendance.findById(id);
    if (!attendance) {
      return res.status(404).json({ success: false, message: 'Attendance record not found' });
    }

    if (field === 'checkin') {
      attendance.checkInTime = undefined;
      attendance.checkInMethod = undefined;
      attendance.checkInMetadata = undefined;
      attendance.checkInPhoto = undefined;
      attendance.checkInLocation = undefined;
    } else {
      attendance.checkOutTime = undefined;
      attendance.checkOutMethod = undefined;
      attendance.checkOutMetadata = undefined;
      attendance.checkOutPhoto = undefined;
      attendance.checkOutLocation = undefined;
    }

    await attendance.save();
    res.json({ success: true, message: `Cleared ${field} info`, data: toVnAttendance(attendance) });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error clearing attendance record',
      error: error.message,
    });
  }
};

// Get my attendance records
exports.getMyAttendance = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;

    let query = { employee: req.user.employeeId };

    if (startDate && endDate) {
      query.date = { $gte: startDate, $lte: endDate };
    }

    const attendances = await Attendance.find(query)
      .populate('shift', 'code name startTime endTime')
      .sort({ checkInTime: -1 });

    res.json({
      success: true,
      count: attendances.length,
      data: attendances.map(toVnAttendance)
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching attendance records', 
      error: error.message 
    });
  }
};

// Get today's attendance status
exports.getTodayStatus = async (req, res) => {
  try {
    const today = toVnDate();
    
    const attendance = await Attendance.findOne({
      employee: req.user.employeeId,
      date: today
    }).populate('shift', 'code name startTime endTime');

    res.json({
      success: true,
      data: attendance ? toVnAttendance(attendance) : { message: 'No attendance record for today' }
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching today status', 
      error: error.message 
    });
  }
};

// Get attendance statistics
exports.getStatistics = async (req, res) => {
  try {
    const { month, year } = req.query;

    const now = new Date();
    const targetYear = year ? String(year) : String(now.getFullYear());
    const targetMonth = month ? String(month).padStart(2, '0') : String(now.getMonth() + 1).padStart(2, '0');

    const startDate = `${targetYear}-${targetMonth}-01`;
    const endDate = `${targetYear}-${targetMonth}-31`;

    const totalDays = await Attendance.countDocuments({
      employee: req.user.employeeId,
      date: { $gte: startDate, $lte: endDate }
    });

    const lateDays = await Attendance.countDocuments({
      employee: req.user.employeeId,
      date: { $gte: startDate, $lte: endDate },
      status: 'late'
    });

    const attendances = await Attendance.find({
      employee: req.user.employeeId,
      date: { $gte: startDate, $lte: endDate },
      workDuration: { $ne: null }
    });

    const totalWorkMinutes = attendances.reduce((sum, att) => sum + att.workDuration, 0);
    const averageWorkHours = attendances.length > 0 
      ? (totalWorkMinutes / attendances.length / 60).toFixed(2) 
      : 0;

    res.json({
      success: true,
      data: {
        totalDays,
        lateDays,
        averageWorkHours,
        totalWorkHours: (totalWorkMinutes / 60).toFixed(2)
      }
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching statistics', 
      error: error.message 
    });
  }
};
