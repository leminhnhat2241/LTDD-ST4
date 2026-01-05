const mongoose = require('mongoose');

const employeeSchema = new mongoose.Schema({
  employeeId: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  fullName: {
    type: String,
    required: true,
    trim: true
  },
  phone: {
    type: String,
    trim: true
  },
  department: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Department',
    required: true
  },
  position: {
    type: String,
    required: true,
    trim: true
  },
  manager: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Employee',
    default: null
  },
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  avatar: {
    type: String,
    default: null
  },
  qrCodeVersion: {
    type: Number,
    default: 1
  },
  qrCodeDataUrl: {
    type: String,
    default: null
  },
  nfcUid: {
    type: String,
    default: null
  },
  employmentType: {
    type: String,
    enum: ['fulltime', 'parttime', 'contract'],
    default: 'fulltime'
  },
  lastCheckInAt: {
    type: Date,
    default: null
  },
  lastCheckOutAt: {
    type: Date,
    default: null
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

employeeSchema.index({ department: 1 });
employeeSchema.index({ nfcUid: 1 }, { unique: true, partialFilterExpression: { nfcUid: { $exists: true, $ne: null } } });

employeeSchema.pre('save', function() {
  this.updatedAt = Date.now();
});

module.exports = mongoose.model('Employee', employeeSchema);
