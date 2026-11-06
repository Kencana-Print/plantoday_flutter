import { describe, it, expect } from "vitest";
import router from "../routes/inkasoRoute";
import inkasoController from "../controllers/inkasoController";
import inkasoService from "../services/inkasoService";

describe("Inkaso / Invoice Jatuh Tempo (Read-Only)", () => {
    it("should export getInvoiceJatuhTempo function in service and controller", () => {
        expect(typeof inkasoService.getInvoiceJatuhTempo).toBe("function");
        expect(typeof inkasoController.getInvoiceJatuhTempo).toBe("function");
    });

    it("should mount /inkaso and /invoice-jatuh-tempo GET routes", () => {
        const routes = router.stack
            .filter((layer) => layer.route)
            .map((layer) => ({
                path: layer.route.path,
                methods: Object.keys(layer.route.methods),
            }));

        expect(routes).toEqual(
            expect.arrayContaining([
                { path: "/inkaso", methods: ["get"] },
                { path: "/invoice-jatuh-tempo", methods: ["get"] },
            ]),
        );
    });
});
