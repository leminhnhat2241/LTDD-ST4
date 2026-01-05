const express = require('express');
const router = express.Router();
const { auth, isAdminOrManager } = require('../middleware/auth');
const departmentController = require('../controllers/departmentController');

// Require auth for all department routes
router.use(auth);

// Admin or manager only
router.post('/', isAdminOrManager, departmentController.createDepartment);
router.get('/', isAdminOrManager, departmentController.getDepartments);
router.get('/:id', isAdminOrManager, departmentController.getDepartmentById);
router.put('/:id', isAdminOrManager, departmentController.updateDepartment);
router.delete('/:id', isAdminOrManager, departmentController.deleteDepartment);

module.exports = router;
