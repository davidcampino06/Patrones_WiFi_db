# WiFiSense-database

Esquema PostgreSQL de WiFiSense: migraciones versionadas, datos de demostración y pruebas del esquema. Solo el
backend se conecta a esta base de datos.

## Contenido

```text
migrations/   V1…V38 en formato Flyway (V<n>__<descripcion>.sql)
seeds/        seed_data.sql: sedes, redes y 24 h de mediciones SIMULADAS (sin usuarios), solo para demostraciones
security/     rol_aplicacion.sql: rol con permisos mínimos para el backend
mantenimiento/ revisar_ y borrar_datos_simulados.sql: dejar el panel del equipo sin datos simulados
tests/        *_test.sql (pruebas), actualizacion_test.sh (actualizar una base con datos),
              revisar_antes_de_aplicar.sql y verificar_*.sql (solo lectura, para Railway)
docs/         schema.md (diagrama, tablas, decisiones e índices), seguridad.md y respaldo.md (copias de seguridad)
apply.sh      aplica migraciones con psql (alternativa a Flyway)
.github/      pruebas automáticas en cada Pull Request (GitHub Actions)
docker-compose.yml  PostgreSQL 16 + Flyway para desarrollo local
```

## Tablas

`users`, `locations`, `zones`, `networks`, `devices`, `measurements`, `traffic_observations`, `traffic_sessions`,
`protocol_statistics`, `analysis_results`, `ai_predictions`, `alerts`, `home_networks`, `connection_tests`,
`agent_keys`, `agent_reports`, `agent_devices`, `password_reset_tokens`, `agent_pairing_codes`, `alert_preferences`,
`agent_alerts`, `refresh_tokens`, `network_sensors`, `network_sensor_pairing_codes`, `network_sensor_reports`,
`network_sensor_devices`, `agent_device_sessions`, `network_sensor_device_sessions` y `ai_model_versions`. Relaciones, restricciones e índices explicados en [docs/schema.md](docs/schema.md).

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
| V34 | Fuente `AGENT`: las redes del equipo se miden con su sensor (es la fuente por defecto); la fuente de cada medición debe ser una conocida |
| V35 | `network_sensors` y `network_sensor_pairing_codes`: el sensor de cada red del equipo (el agente WiFiSense instalado en esa red) y su código de 8 caracteres; solo se guarda el SHA-256 de la clave y del código |
| V36 | `network_sensor_reports` y `network_sensor_devices`: lo que ve el sensor de cada red del equipo, como Mi Wi-Fi: cada reporte con la auditoría de seguridad, la calidad y el mejor canal, y los equipos conectados (solo la huella con sal de la MAC, fabricante, nombre, si usa dirección privada y si un administrador lo marcó como no autorizado) |
| V37 | `agent_device_sessions` y `network_sensor_device_sessions`: cada periodo en que un equipo estuvo conectado (de Mi Wi-Fi o de una red del equipo), con un solo periodo abierto por equipo; se borran con el equipo |
| V38 | Identificar equipos: `kind` (celular, computador, televisor, impresora, cámara, parlante, consola o IoT), `role` (el computador del agente o el router) y `model` en los equipos; `identify_until` en el agente y el sensor (reportar cada minuto mientras se identifica un equipo). `ai_model_versions`: cada entrenamiento de la IA con mediciones reales, sus métricas, si reemplazó al modelo en uso (uno solo activo) y los datos para reconstruirlo |

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
3. Ejecuta `tests/verificar_base_terminada.sql`, `tests/verificar_sensor.sql` (y los `verificar_*.sql`
   anteriores): todas las filas en `OK`.

### Dejar el panel del equipo sin datos simulados

1. `mantenimiento/revisar_datos_simulados.sql` (no cambia nada): qué redes, mediciones y sedes de demostración se
   borrarán y qué se queda (cuentas, redes de Mi Wi-Fi y redes reales del equipo).
2. `mantenimiento/borrar_datos_simulados.sql`: lo borra todo en una sola transacción y muestra lo que queda.

Las redes simuladas se borran con todo lo que depende de ellas (equipos, mediciones, tráfico, análisis, alertas).
Nunca toca cuentas, redes de Mi Wi-Fi, sus agentes ni sus reportes.

`DATABASE_URL` aquí usa el formato de `psql`. El backend usa el mismo servidor con formato JDBC
(`jdbc:postgresql://...`).

## Datos semilla

- No crea usuarios: el backend crea al administrador desde variables de entorno y él crea las demás cuentas.
- 2 sedes, 4 zonas, 4 redes. `WiFiSense-Guest` (2.4 GHz, abierta) tiene métricas degradadas a propósito para que
  el análisis encuentre algo.
- 96 mediciones por red (24 h cada 15 min), tráfico, protocolos, 7 dispositivos y sesiones.
- **Todas las redes y mediciones son simuladas** y lo indican (`data_source_type` y `source` = `'SIMULATION'`). Son
  solo para demostraciones locales; en Railway se borran con `mantenimiento/borrar_datos_simulados.sql`.

## Seguridad

El backend debería conectarse con el rol `wifisense_app` (`security/rol_aplicacion.sql`): puede leer y escribir
datos, pero no crear, cambiar ni borrar tablas, ni vaciar una tabla de golpe; una consulta que pase de 30 s se
corta. Las migraciones siguen corriendo con el dueño de la base. Paso a paso en [docs/seguridad.md](docs/seguridad.md).
Los tokens (enlaces de recuperación, códigos del agente, claves del agente y refresh tokens) se guardan solo como
SHA-256, y de los equipos del usuario nunca se guarda la MAC. Antes de cada migración en Railway haz una copia de
seguridad: [docs/respaldo.md](docs/respaldo.md).
Quién puede conectarse a la base y con qué usuario: [docs/seguridad.md](docs/seguridad.md#quién-puede-conectarse).

## Pruebas

`bash apply.sh --test` corre todas las pruebas; cada una se detiene en la primera falla con `FAILED: <descripción>`:

| Archivo | Qué comprueba |
|---|---|
| `schema_test.sql` | Las 29 tablas y 30 claves foráneas, que las restricciones rechazan datos inválidos (rol inexistente, MAC mal formada, pérdida > 100 %, alerta resuelta sin fecha…) y que los datos semilla son coherentes |
| `optimizacion_test.sql` | Que ninguna clave foránea quede sin índice y que la limpieza por fecha y las consultas frecuentes usen su índice (con `EXPLAIN`) |
| `integridad_test.sql` | Cuentas únicas sin importar mayúsculas, correos normalizados, nombres no vacíos, JSON como objeto y refresh tokens |
| `diccionario_test.sql` | Que todas las tablas y columnas tengan descripción |
| `rol_aplicacion_test.sql` | Que el rol de la aplicación trabaje con los datos pero no pueda cambiar el esquema |
| `sensor_test.sql` | La fuente `AGENT`, un sensor y un código vigente por red, claves y códigos solo como SHA-256 y que todo se borre con la red |
| `sensor_reportes_test.sql` | Reportes y equipos del sensor (V36): JSON como objeto, equipos nunca con la MAC, nombres no vacíos y que todo se borre con la red |
| `sesiones_test.sql` | Historial de conexiones (V37): un solo periodo abierto por equipo, fechas coherentes y que se borre con el equipo o la red |
| `carga_test.sql` | Un mes de uso real de tres redes (78 000 mediciones, 39 000 de tráfico, 600 equipos y 15 000 periodos de conexión): las consultas más usadas del backend usan su índice y responden en tiempo (últimas 50 mediciones < 50 ms, semana por día < 300 ms, datos de entrenamiento de la IA < 2 s); en local tardan 0,2 ms, 4 ms y 26 ms |
| `privacidad_test.sql` | Borrar una cuenta borra todo lo suyo (redes, clave y código del agente, reportes, equipos con sus nombres, periodos de conexión, alertas, pruebas de conexión, preferencias, sesiones y enlaces de recuperación) sin tocar los datos del equipo; y ninguna tabla que apunte a una cuenta, red de casa o equipo puede quedarse con sus datos (todas sus llaves foráneas son `CASCADE` o `SET NULL`) |
| `identidad_modelo_test.sql` | Tipo, rol y modelo de los equipos con valores conocidos (V38) y versiones del modelo: una sola activa, nunca una rechazada, periodo en orden y que el historial quede aunque se borre la cuenta |

`tests/actualizacion_test.sh` crea una base como la de producción (hasta V25, con datos que incluyen los casos
difíciles), aplica las migraciones nuevas y comprueba que no se pierda ninguna fila; también comprueba que V28 se
detenga sin cambiar nada si hay cuentas repetidas. Además reproduce la producción de hoy (hasta V37, con el rol de la
aplicación): aplica V38, comprueba que `wifisense_app` ya puede usar las tablas nuevas sin permisos extra y que la
limpieza borra todo lo simulado sin tocar cuentas, redes de Mi Wi-Fi ni redes reales.

**GitHub Actions** (`.github/workflows/base-de-datos.yml`) corre en cada Pull Request, sobre PostgreSQL 16: todas
las migraciones desde cero, los datos semilla, el rol, todas las pruebas, la limpieza de datos simulados, las verificaciones de solo lectura, la
actualización sobre una base con datos y Flyway aplicando los mismos archivos.

`tests/verificar_agente.sql` comprueba, sin modificar nada, que una base existente (por ejemplo la de Railway) ya
tiene V17–V19, `tests/verificar_recuperacion.sql` lo mismo para V20–V22, `tests/verificar_alertas.sql` para V23–V24, `tests/verificar_identificacion.sql` para V25 y
`tests/verificar_base_terminada.sql` para V26–V33 y `tests/verificar_sensor.sql` para V34–V35 y la limpieza, `tests/verificar_sensor_reportes.sql` para V36, `tests/verificar_sesiones.sql` para V37, `tests/verificar_identidad_modelo.sql` para V38: cada fila debe decir `OK`. `docs/consultas_agente.sql` trae consultas de solo lectura para revisar en
DBeaver las claves, los reportes, las vulnerabilidades y los equipos que envía el agente.
