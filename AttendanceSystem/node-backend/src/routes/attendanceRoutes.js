const express = require('express');
const router = express.Router();
const attendanceController = require('../controllers/attendanceController');
const { auth, isAdminOrManager } = require('../middleware/auth');

// Allow kiosk (QR/NFC) public; require admin/manager for manual/employee_id
const guardManualEntry = (req, res, next) => {
	const method = (req.body.method || '').toLowerCase();
	if (['qr', 'nfc', 'fingerprint'].includes(method)) {
		return next();
	}
	return auth(req, res, () => isAdminOrManager(req, res, next));
};

// Methods listing (public)
router.get('/method', attendanceController.getMethods);

router.post('/check-in', guardManualEntry, attendanceController.checkIn);
router.post('/check-out', guardManualEntry, attendanceController.checkOut);

// Protected routes
router.use(auth);

// Get my attendance records
router.get('/my-records', attendanceController.getMyAttendance);

// Get today's status
router.get('/today', attendanceController.getTodayStatus);

// Get statistics
router.get('/statistics', attendanceController.getStatistics);

// Report (admin/manager)
router.get('/report', isAdminOrManager, attendanceController.getReport);

// Get all attendance records (admin/manager only)
router.get('/', isAdminOrManager, attendanceController.getAttendanceRecords);

// Clear specific attendance parts (admin/manager only)
router.patch('/:id', isAdminOrManager, attendanceController.clearAttendanceField);

// Delete an attendance record (admin/manager only)
router.delete('/:id', isAdminOrManager, attendanceController.deleteAttendance);

module.exports = router;
