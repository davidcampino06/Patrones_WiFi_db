# WiFiSense-database

Esquema PostgreSQL de WiFiSense: migraciones versionadas, datos de demostración y pruebas del esquema. Solo el
backend se conecta a esta base de datos.

## Contenido

```text
migrations/   V1…V14 en formato Flyway (V<n>__<descripcion>.sql)
seeds/        seed_data.sql: sedes, redes y 24 h de mediciones SIMULADAS (sin usuarios)
tests/        schema_test.sql: estructura, restricciones y datos semilla
docs/         schema.md: diagrama entidad-relación, tablas, decisiones e índices
apply.sh      aplica migraciones con psql (alternativa a Flyway)
docker-compose.yml  PostgreSQL 16 + Flyway para desarrollo local
```

## Tablas

`users`, `locations`, `zones`, `networks`, `devices`, `measurements`, `traffic_observations`, `traffic_sessions`,
`protocol_statistics`, `analysis_results`, `ai_predictions`, `alerts`, `home_networks`, `connection_tests`, `agent_keys`, `agent_reports`, `agent_devices`, `password_reset_tokens` y `agent_pairing_codes`. Relaciones, restricciones e índices
explicados en [docs/schema.md](docs/schema.md).

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
./apply.sh --seed --test      # migraciones + datos de demostración + pruebas
```

`DATABASE_URL` aquí usa el formato de `psql`. El backend usa el mismo servidor con formato JDBC
(`jdbc:postgresql://...`).

## Datos semilla

- No crea usuarios: el backend crea al administrador desde variables de entorno y él crea las demás cuentas.
- 2 sedes, 4 zonas, 4 redes. `WiFiSense-Guest` (2.4 GHz, abierta) tiene métricas degradadas a propósito para que
  el análisis encuentre algo.
- 96 mediciones por red (24 h cada 15 min), tráfico, protocolos, 7 dispositivos y sesiones.
- **Todas las mediciones son simuladas** y lo indican con `source = 'SIMULATION'`.

## Pruebas

`tests/schema_test.sql` comprueba que existen las 19 tablas y 20 claves foráneas, que las restricciones rechazan
datos inválidos (rol inexistente, MAC mal formada, pérdida > 100 %, alerta resuelta sin fecha…) y que los datos
semilla son coherentes. Cualquier fallo detiene la ejecución con `FAILED: <descripción>`.

`tests/verificar_agente.sql` comprueba, sin modificar nada, que una base existente (por ejemplo la de Railway) ya
tiene V17–V19, y `tests/verificar_recuperacion.sql` lo mismo para V20–V22: cada fila debe decir `OK`. `docs/consultas_agente.sql` trae consultas de solo lectura para revisar en
DBeaver las claves, los reportes, las vulnerabilidades y los equipos que envía el agente.
