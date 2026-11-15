const express = require("express");
const router = express.Router();
const auth = require("../middleware/auth");
const inkasoController = require("../controllers/inkasoController");

// List & ringkasan invoice jatuh tempo (read-only)
router.get("/inkaso", auth, inkasoController.getInvoiceJatuhTempo);
router.get("/invoice-jatuh-tempo", auth, inkasoController.getInvoiceJatuhTempo);

module.exports = router;
