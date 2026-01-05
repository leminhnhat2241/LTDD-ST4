const mongoose = require('mongoose');

const deviceSchema = new mongoose.Schema({
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
  deviceType: {
    type: String,
    enum: ['attendance'],
    default: 'attendance'
  },
  status: {
    type: String,
    enum: ['active', 'inactive'],
    default: 'active'
  },
  location: {
    latitude: Number,
    longitude: Number,
    address: String
  },
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  lastSeenAt: {
    type: Date,
    default: null
  },
  registeredAt: {
    type: Date,
    default: Date.now
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

deviceSchema.pre('save', function() {
  this.updatedAt = Date.now();
});

module.exports = mongoose.model('Device', deviceSchema);
