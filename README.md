# WiFiSense-database

Esquema PostgreSQL de WiFiSense: migraciones versionadas, datos de demostración y pruebas del esquema. Solo el
backend se conecta a esta base de datos.

## Contenido

```text
migrations/   V1…V33 en formato Flyway (V<n>__<descripcion>.sql)
seeds/        seed_data.sql: sedes, redes y 24 h de mediciones SIMULADAS (sin usuarios)
security/     rol_aplicacion.sql: rol con permisos mínimos para el backend
tests/        *_test.sql (pruebas), actualizacion_test.sh (actualizar una base con datos),
              revisar_antes_de_aplicar.sql y verificar_*.sql (solo lectura, para Railway)
docs/         schema.md (diagrama, tablas, decisiones e índices) y seguridad.md
apply.sh      aplica migraciones con psql (alternativa a Flyway)
.github/      pruebas automáticas en cada Pull Request (GitHub Actions)
docker-compose.yml  PostgreSQL 16 + Flyway para desarrollo local
```

## Tablas

`users`, `locations`, `zones`, `networks`, `devices`, `measurements`, `traffic_observations`, `traffic_sessions`,
`protocol_statistics`, `analysis_results`, `ai_predictions`, `alerts`, `home_networks`, `connection_tests`,
`agent_keys`, `agent_reports`, `agent_devices`, `password_reset_tokens`, `agent_pairing_codes`, `alert_preferences`,
`agent_alerts` y `refresh_tokens`. Relaciones, restricciones e índices explicados en [docs/schema.md](docs/schema.md).

Cada tabla y cada columna tiene su descripción dentro de la propia base (`COMMENT ON`, V31–V33): en DBeaver se ve
en la pestaña *Properties* de cada tabla. Una prueba falla si alguien agrega una tabla o columna sin describirla.

## Migraciones

| Versión | Contenido |
|---|---|
| V1 | `users` |
| V2 | `locations`, `zones` |
| V3 | `networks` |
| V4 | `devices` |
| V5 | `measurements` |
| V6 | `traffic_observations`, `traffic_sessions`, `protocol_statistics` |
| V7 | `analysis_results`, `ai_predictions` |
| V8 | `alerts` |
| V9 | índices según las consultas del backend |
| V10 | elimina las cuentas de demostración y limita el usuario a 20 caracteres |
| V11 | recomendaciones de IA de hasta 1500 caracteres y su origen (`RULES` o `CLAUDE`) |
| V12 | el usuario puede ser un correo: límite de 40 caracteres |
| V13 | rol `USER` para los usuarios finales que se registran solos |
| V14 | `home_networks`: redes que cada usuario final registra para sí (separadas de las de la universidad) |
| V15 | `ai_predictions.anomaly_type`: causa probable de cada anomalía según el diagnóstico de la IA |
| V16 | `connection_tests`: pruebas de conexión de los usuarios finales y su calificación de calidad |
| V17 | `agent_keys`: clave del agente WiFiSense de cada red (solo su SHA-256) |
| V18 | `agent_reports`: reportes del agente con la auditoría de seguridad, la calidad y las anomalías que da la IA |
| V19 | `agent_devices`: equipos vistos en cada red (huella con sal, nunca la MAC) y el nombre que les pone el usuario |
| V20 | `users.phone` (formato internacional) y `users.password_changed_at` (cerrar sesiones al cambiar la contraseña) |
| V21 | `password_reset_tokens`: enlaces de recuperación por correo, de un solo uso y con vencimiento (solo su SHA-256) |
| V22 | `agent_pairing_codes`: código corto para instalar el agente sin copiar la clave larga |
| V23 | `agent_devices.vendor` (fabricante según el OUI), `hostname` (nombre del equipo en la red) y `authorized` (equipo marcado como no autorizado) |
| V24 | `alert_preferences` y `agent_alerts`: avisos por correo (equipo nuevo, seguridad, anomalía) y su historial |
| V25 | `agent_devices.private_mac` (celular o tableta con MAC aleatoria) e índice parcial de anomalías para el panel del equipo |
| V26 | Índices para las tres claves foráneas que no tenían (borrar una cuenta, una red o un análisis ya no recorre tablas enteras) |
| V27 | Índices por fecha para la limpieza nocturna de mediciones, tráfico, análisis, alertas resueltas y códigos vencidos |
| V28 | Usuario y correo únicos sin importar mayúsculas; los correos se guardan en minúsculas (un disparador los normaliza). Se detiene con un mensaje claro si ya hay cuentas repetidas |
| V29 | Reglas que antes solo validaba el backend: nombres no vacíos en sedes y zonas, piso entre -10 y 200, JSON siempre como objeto |
| V30 | `refresh_tokens`: sesión que se renueva sola, con rotación y revocación de toda la familia si un token se reutiliza |
| V31–V33 | Diccionario de datos: descripción de las 22 tablas y de todas sus columnas |

Las migraciones reconstruyen la base de datos desde cero. Nunca se edita una migración ya aplicada: los cambios
van en una versión nueva (`V10__...`).

## Uso

Con Docker (PostgreSQL + Flyway):

```bash
cp .env.example .env          # define POSTGRES_PASSWORD
docker compose up -d postgres
docker compose run --rm flyway
psql "postgresql://wifisense:<password>@localhost:5432/wifisense" -f seeds/seed_data.sql
```

Con un PostgreSQL existente:

```bash
export DATABASE_URL=postgresql://wifisense:<password>@localhost:5432/wifisense
bash apply.sh --seed --test             # migraciones + datos de demostración + pruebas
bash apply.sh --seed --security --test  # además, el rol de la aplicación (necesita un superusuario)
```

### Aplicar migraciones nuevas en una base con datos (Railway, desde DBeaver)

1. Ejecuta `tests/revisar_antes_de_aplicar.sql`: no cambia nada y cada fila debe decir `OK`. Si alguna dice
   `REVISAR`, corrige esos datos primero (por ejemplo, dos cuentas `Carlos` y `carlos`).
2. Ejecuta las migraciones nuevas, una por una y en orden.
3. Ejecuta `tests/verificar_base_terminada.sql` (y los `verificar_*.sql` anteriores): todas las filas en `OK`.

`DATABASE_URL` aquí usa el formato de `psql`. El backend usa el mismo servidor con formato JDBC
(`jdbc:postgresql://...`).

## Datos semilla

- No crea usuarios: el backend crea al administrador desde variables de entorno y él crea las demás cuentas.
- 2 sedes, 4 zonas, 4 redes. `WiFiSense-Guest` (2.4 GHz, abierta) tiene métricas degradadas a propósito para que
  el análisis encuentre algo.
- 96 mediciones por red (24 h cada 15 min), tráfico, protocolos, 7 dispositivos y sesiones.
- **Todas las mediciones son simuladas** y lo indican con `source = 'SIMULATION'`.

## Seguridad

El backend debería conectarse con el rol `wifisense_app` (`security/rol_aplicacion.sql`): puede leer y escribir
datos, pero no crear, cambiar ni borrar tablas, ni vaciar una tabla de golpe; una consulta que pase de 30 s se
corta. Las migraciones siguen corriendo con el dueño de la base. Paso a paso en [docs/seguridad.md](docs/seguridad.md).
Los tokens (enlaces de recuperación, códigos del agente, claves del agente y refresh tokens) se guardan solo como
SHA-256, y de los equipos del usuario nunca se guarda la MAC.

## Pruebas

`bash apply.sh --test` corre todas las pruebas; cada una se detiene en la primera falla con `FAILED: <descripción>`:

| Archivo | Qué comprueba |
|---|---|
| `schema_test.sql` | Las 22 tablas y 23 claves foráneas, que las restricciones rechazan datos inválidos (rol inexistente, MAC mal formada, pérdida > 100 %, alerta resuelta sin fecha…) y que los datos semilla son coherentes |
| `optimizacion_test.sql` | Que ninguna clave foránea quede sin índice y que la limpieza por fecha y las consultas frecuentes usen su índice (con `EXPLAIN`) |
| `integridad_test.sql` | Cuentas únicas sin importar mayúsculas, correos normalizados, nombres no vacíos, JSON como objeto y refresh tokens |
| `diccionario_test.sql` | Que todas las tablas y columnas tengan descripción |
| `rol_aplicacion_test.sql` | Que el rol de la aplicación trabaje con los datos pero no pueda cambiar el esquema |

`tests/actualizacion_test.sh` crea una base como la de producción (hasta V25, con datos que incluyen los casos
difíciles), aplica las migraciones nuevas y comprueba que no se pierda ninguna fila; también comprueba que V28 se
detenga sin cambiar nada si hay cuentas repetidas.

**GitHub Actions** (`.github/workflows/base-de-datos.yml`) corre en cada Pull Request, sobre PostgreSQL 16: todas
las migraciones desde cero, los datos semilla, el rol, todas las pruebas, las verificaciones de solo lectura, la
actualización sobre una base con datos y Flyway aplicando los mismos archivos.

`tests/verificar_agente.sql` comprueba, sin modificar nada, que una base existente (por ejemplo la de Railway) ya
tiene V17–V19, `tests/verificar_recuperacion.sql` lo mismo para V20–V22, `tests/verificar_alertas.sql` para V23–V24, `tests/verificar_identificacion.sql` para V25 y
`tests/verificar_base_terminada.sql` para V26–V33: cada fila debe decir `OK`. `docs/consultas_agente.sql` trae consultas de solo lectura para revisar en
DBeaver las claves, los reportes, las vulnerabilidades y los equipos que envía el agente.
