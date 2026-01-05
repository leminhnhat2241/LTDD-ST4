const mongoose = require('mongoose');

const attendanceSchema = new mongoose.Schema({
  employee: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Employee',
    required: true
  },
  employeeId: {
    type: String,
    required: true
  },
  department: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Department',
    required: true
  },
  shift: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Shift',
    default: null
  },
  device: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Device',
    default: null
  },
  date: {
    type: String, // YYYY-MM-DD
    required: true
  },
  checkInTime: {
    type: Date,
    default: null
  },
  checkOutTime: {
    type: Date,
    default: null
  },
  checkInMethod: {
    type: String,
    enum: ['nfc', 'qr', 'manual', 'employee_id', 'fingerprint'],
    required: true
  },
  checkOutMethod: {
    type: String,
    enum: ['nfc', 'qr', 'manual', 'employee_id', 'fingerprint'],
    default: null
  },
  checkInMetadata: {
    fingerprintId: String
  },
  checkOutMetadata: {
    fingerprintId: String
  },
  checkInPhoto: {
    type: String, // base64-encoded image (data URL or plain base64)
    default: null
  },
  checkOutPhoto: {
    type: String,
    default: null
  },
  checkInLocation: {
    latitude: Number,
    longitude: Number,
    address: String
  },
  checkOutLocation: {
    latitude: Number,
    longitude: Number,
    address: String
  },
  fallbackUsed: {
    type: Boolean,
    default: false
  },
  fallbackReason: {
    type: String,
    default: null
  },
  status: {
    type: String,
    enum: ['on-time', 'late', 'early-leave', 'absent', 'pending-adjust'],
    default: 'on-time'
  },
  workDuration: {
    type: Number, // minutes
    default: null
  },
  notes: {
    type: String,
    default: ''
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

attendanceSchema.index({ employee: 1, date: 1 }, { unique: true });
attendanceSchema.index({ department: 1, date: 1 });
attendanceSchema.index({ device: 1, date: 1 });

attendanceSchema.pre('save', function() {
  if (this.checkOutTime && this.checkInTime) {
    const duration = (this.checkOutTime - this.checkInTime) / (1000 * 60);
    this.workDuration = Math.round(duration);
  }
  this.updatedAt = Date.now();
});

module.exports = mongoose.model('Attendance', attendanceSchema);
