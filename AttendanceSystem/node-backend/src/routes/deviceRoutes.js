const express = require('express');
const router = express.Router();
const deviceController = require('../controllers/deviceController');
const { auth, isAdminOrManager } = require('../middleware/auth');

// All device routes require admin or manager
router.use(auth, isAdminOrManager);

router.post('/', deviceController.createDevice);
router.get('/', deviceController.getDevices);
router.get('/:id', deviceController.getDeviceById);
router.put('/:id', deviceController.updateDevice);
router.delete('/:id', deviceController.deleteDevice);

module.exports = router;
