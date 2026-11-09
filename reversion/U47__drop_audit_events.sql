-- Reversión de V47 (auditoría). Úsala solo si se revierte el Avance 24 del backend: borra la auditoría guardada.
-- Antes: respaldo con pg_dump (docs/respaldo.md). Todo en una transacción: si algo falla, no cambia nada.
BEGIN;
DROP TRIGGER IF EXISTS trg_audit_events_protect ON audit_events;
DROP TABLE IF EXISTS audit_events;
DROP FUNCTION IF EXISTS audit_events_protect();
DO $$ BEGIN
    IF to_regclass('flyway_schema_history') IS NOT NULL THEN
        DELETE FROM flyway_schema_history WHERE version = '47';
    END IF;
END $$;
COMMIT;
