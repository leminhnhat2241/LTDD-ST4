const mongoose = require('mongoose');

const shiftSchema = new mongoose.Schema({
  code: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  startTime: {
    type: String, // HH:mm
    required: true
  },
  endTime: {
    type: String, // HH:mm
    required: true
  },
  graceLateMinutes: {
    type: Number,
    default: 0
  },
  earlyLeaveMinutes: {
    type: Number,
    default: 0
  },
  daysOfWeek: {
    type: [Number], // 0-6 (Sun-Sat)
    default: [1, 2, 3, 4, 5]
  },
  isFlexible: {
    type: Boolean,
    default: false
  },
  isActive: {
    type: Boolean,
    default: true
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

shiftSchema.pre('save', function() {
  this.updatedAt = Date.now();
});

module.exports = mongoose.model('Shift', shiftSchema);
