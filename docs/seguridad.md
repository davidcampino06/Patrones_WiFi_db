# Seguridad de la base de datos

## Rol de la aplicación con permisos mínimos

Hoy el backend en Railway se conecta con el dueño de la base (`postgres`), que puede hacer cualquier cosa: crear,
cambiar o borrar tablas. Si un error del backend o una inyección SQL llegara a ejecutar algo así, el daño sería total.
`security/rol_aplicacion.sql` crea `wifisense_app`, que solo puede trabajar con los datos:

| Puede | No puede |
|---|---|
| `SELECT`, `INSERT`, `UPDATE`, `DELETE` en las tablas | Crear, cambiar (`ALTER`) o borrar (`DROP`) tablas |
| Usar las secuencias de los identificadores | Vaciar una tabla de golpe (`TRUNCATE`) |
| Tablas que agreguen migraciones futuras (privilegios por defecto) | Crear roles ni bases de datos; tocar `flyway_schema_history` |

Además, una consulta que pase de 30 segundos se corta (`statement_timeout`) y una transacción olvidada abierta se
cierra al minuto (`idle_in_transaction_session_timeout`): nada del backend tarda tanto, así que solo afecta a algo
que salió mal. La contraseña **no está en el repositorio**: se escribe a mano una sola vez.

### Activarlo en Railway

1. **DBeaver**, conexión `railway` (usuario `postgres`): abre `security/rol_aplicacion.sql` y ejecútalo completo con
   **Alt + X**. Se puede volver a ejecutar sin problema.
2. En el mismo editor escribe y ejecuta (inventa una contraseña larga; no la guardes en ningún archivo):

   ```sql
   ALTER ROLE wifisense_app LOGIN PASSWORD 'pon-aqui-una-contraseña-larga';
   ```

3. Comprueba: `tests/verificar_base_terminada.sql` debe mostrar *Rol de la aplicación* en `OK`.
4. **Railway → servicio del backend → Variables**: cambia `DATABASE_USERNAME` a `wifisense_app` y
   `DATABASE_PASSWORD` a la contraseña del paso 2. Railway redespliega solo; espera **Active**.
5. Si el backend no arranca (por ejemplo, contraseña mal copiada), vuelve a poner `DATABASE_USERNAME=postgres` y su
   contraseña anterior: todo queda como antes.

Las migraciones nuevas se siguen ejecutando en DBeaver con el usuario `postgres`; gracias a los privilegios por
defecto, las tablas que creen quedan disponibles para `wifisense_app` sin repetir el paso 1.

## Datos que nunca se guardan en claro

| Dato | Cómo se guarda |
|---|---|
| Contraseñas | Hash BCrypt (`users.password_hash`) |
| Enlaces de recuperación, códigos de instalación, claves del agente y refresh tokens | Solo su SHA-256: una copia de la base no sirve para entrar |
| MAC de los equipos del usuario | Nunca llega: el agente envía una huella SHA-256 con sal propia de cada instalación |

Cada formato está protegido con un `CHECK` (por ejemplo, `token_hash ~ '^[0-9a-f]{64}$'`), así que un error que
intentara guardar el valor en claro sería rechazado por la base.
