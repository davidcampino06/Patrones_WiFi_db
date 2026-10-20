# Respaldo y restauración de la base de datos

La base de producción está en Railway. Un respaldo es una copia de **toda** la base (estructura y datos) en un archivo,
para volver a un punto anterior si algo sale mal (una migración aplicada a medias, datos borrados por error) o para
llevar la base a otro servidor.

> El archivo de respaldo contiene las contraseñas cifradas de los usuarios, sus correos y las mediciones de sus redes.
> Trátalo como un dato sensible: guárdalo solo en tu computador o en una carpeta privada, **nunca** en un repositorio,
> un chat ni un correo.

## Cuándo hacer un respaldo

- **Siempre antes de aplicar una migración nueva** en Railway (por ejemplo antes de ejecutar `V38__...sql`).
- Antes de borrar datos (`mantenimiento/borrar_datos_simulados.sql`).
- Una vez por semana mientras el proyecto esté en uso.

## Hacer el respaldo (DBeaver)

1. Railway → servicio **Postgres** → *Settings → Networking* → **Add Public Access** (solo mientras dure el respaldo).
2. En DBeaver, conéctate con el usuario `postgres` (los datos de conexión están en Railway → Postgres → *Variables*;
   no los copies a ningún archivo del proyecto).
3. Clic derecho sobre la base `railway` → **Herramientas → Backup** (Tools → Backup).
4. Marca el esquema `public`, formato **Custom**, y elige un archivo como `wifisense-AAAA-MM-DD.backup`.
5. **Iniciar.** DBeaver usa `pg_dump`; si pregunta por el cliente local de PostgreSQL, indícale la carpeta `bin` de
   PostgreSQL 16 instalado en tu computador.
6. Quita el **Public Access** de Postgres en Railway.

El mismo respaldo por consola (con PostgreSQL 16 instalado y la URL pública en una variable, nunca escrita en un archivo):

```cmd
pg_dump --format=custom --no-owner --file=wifisense-2026-10-19.backup "%DATABASE_PUBLIC_URL%"
```

## Restaurar

Restaurar **reemplaza** lo que haya en la base de destino. Pruébalo primero en una base local:

```cmd
createdb wifisense_restaurada
pg_restore --no-owner --dbname=wifisense_restaurada wifisense-2026-10-19.backup
for %f in (tests\verificar_*.sql) do psql -d wifisense_restaurada -f %f
```

Cada verificación debe mostrar todas sus filas en `OK` (la de permisos dirá `FALTA` hasta ejecutar
`security/rol_aplicacion.sql` en esa base). Si el respaldo se restaura en Railway (en una base
nueva o después de vaciarla), ejecuta también `security/rol_aplicacion.sql` para que el rol `wifisense_app` tenga sus
permisos, y pon su contraseña a mano como en [seguridad.md](seguridad.md).

## Qué no hace falta respaldar

- El **modelo de IA**: el backend lo reconstruye con las mediciones guardadas en `ai_model_versions.training_set`.
- Las **claves de los agentes**: solo se guarda su SHA-256; si se pierde la base, cada agente se vuelve a conectar con
  un código nuevo.
