const express = require('express');
const router = express.Router();
const employeeController = require('../controllers/employeeController');
const { auth, isAdmin, isAdminOrManager } = require('../middleware/auth');

// All routes require authentication
router.use(auth);

// Create employee (admin or manager)
router.post('/', isAdminOrManager, employeeController.createEmployee);

// Get all employees (admin/manager only)
router.get('/', isAdminOrManager, employeeController.getAllEmployees);

// Get employee by ID
router.get('/:id', employeeController.getEmployeeById);

// Update employee (admin or manager)
router.put('/:id', isAdminOrManager, employeeController.updateEmployee);

// Delete employee (admin or manager)
router.delete('/:id', isAdminOrManager, employeeController.deleteEmployee);

// Regenerate QR code (admin or manager)
router.post('/:id/regenerate-qr', isAdminOrManager, employeeController.regenerateQRCode);

module.exports = router;
