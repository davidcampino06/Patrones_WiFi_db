# WiFiSense-database

Esquema PostgreSQL de WiFiSense: migraciones versionadas, datos de demostración y pruebas del esquema. Solo el
backend se conecta a esta base de datos.

## Contenido

```text
migrations/   V1…V9 en formato Flyway (V<n>__<descripcion>.sql)
seeds/        seed_data.sql: usuarios, sedes, redes y 24 h de mediciones SIMULADAS
tests/        schema_test.sql: estructura, restricciones y datos semilla
docs/         schema.md: diagrama entidad-relación, tablas, decisiones e índices
apply.sh      aplica migraciones con psql (alternativa a Flyway)
docker-compose.yml  PostgreSQL 16 + Flyway para desarrollo local
```

## Tablas

`users`, `locations`, `zones`, `networks`, `devices`, `measurements`, `traffic_observations`, `traffic_sessions`,
`protocol_statistics`, `analysis_results`, `ai_predictions`, `alerts`. Relaciones, restricciones e índices
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

- Usuarios `admin`, `analyst`, `viewer` (uno por rol). Contraseña de demostración en el encabezado de
  `seeds/seed_data.sql`; cámbiala fuera del entorno local.
- 2 sedes, 4 zonas, 4 redes. `WiFiSense-Guest` (2.4 GHz, abierta) tiene métricas degradadas a propósito para que
  el análisis encuentre algo.
- 96 mediciones por red (24 h cada 15 min), tráfico, protocolos, 7 dispositivos y sesiones.
- **Todas las mediciones son simuladas** y lo indican con `source = 'SIMULATION'`.

## Pruebas

`tests/schema_test.sql` comprueba que existen las 12 tablas y 13 claves foráneas, que las restricciones rechazan
datos inválidos (rol inexistente, MAC mal formada, pérdida > 100 %, alerta resuelta sin fecha…) y que los datos
semilla son coherentes. Cualquier fallo detiene la ejecución con `FAILED: <descripción>`.
