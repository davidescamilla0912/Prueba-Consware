# Sistema de reembolso de gastos

Prueba técnica Fullstack de Consware. Permite que un empleado registre un gasto y consulte su estado, con una API central que aplica la política de aprobación. Un aprobador revisa las solicitudes desde un panel web y aprueba o rechaza con motivo.

## 1. Descripción y alcance

- Un empleado crea una solicitud de reembolso (monto, categoría, descripción) y consulta sus solicitudes.
- La API decide el estado al crear la solicitud:
  - Monto menor o igual a 500.000 COP: se aprueba automáticamente.
  - Monto mayor a 500.000 COP: queda en `Pending`.
- Una solicitud `Pending` puede aprobarse o rechazarse. El rechazo exige un motivo no vacío.
- Una solicitud aprobada o rechazada no vuelve a cambiar de estado (409 si se intenta).
- Los datos se guardan en SQL Server.
- El aprobador filtra por estado, busca por empleado, ve el detalle y decide desde el panel Angular.

### Estado actual

| Componente | Estado |
|---|---|
| API REST (ASP.NET Core + SQL Server) | Implementada. Matriz T01–T16 automatizada: **18/18 PASS** |
| App Flutter (empleado) | Implementada, con pruebas de integración en `mobile/integration_test/` |
| Panel Angular (aprobador) | Implementado: build OK, **10/10 tests**, render y CORS verificados |
| Fechas UTC en el JSON | Corregidas: `createdAtUtc`/`decidedAtUtc` terminan en `Z` |

## 2. Tecnologías

- ASP.NET Core (.NET 9), Entity Framework Core, SQL Server
- Flutter (paquete `http`)
- Angular 22 (standalone, `provideHttpClient`, SCSS) con Vitest

## 3. Requisitos previos

- .NET SDK 9 y la herramienta `dotnet-ef` (`dotnet tool install --global dotnet-ef`)
- SQL Server accesible (en desarrollo: instancia local `localhost\SQLEXPRESS`)
- Flutter SDK y un emulador Android (o Chrome)
- Node.js 20+ con npm (para Angular)

## 4. Configuración de SQL Server

El connection string está en `consware-reembolsos/backend/Consware.Reimbursements.Api/appsettings.json`, con autenticación integrada de Windows:

```
Server=localhost\SQLEXPRESS;Database=ConswareReembolsosDB;Trusted_Connection=True;TrustServerCertificate=True
```

El nombre de instancia es local. En otro equipo hay que cambiar `Server=` por el nombre de su instancia (y revisar permisos de la identidad de Windows sobre la base).

El esquema se crea con migraciones de EF Core, desde `consware-reembolsos/backend/Consware.Reimbursements.Api`:

```
dotnet ef database update
```

La migración inicial (`20261031142239_InitialCreate`) ya está en el repositorio; sólo hace falta `dotnet ef migrations add <Nombre>` si cambia el modelo. Detener la API antes de estos comandos, porque recompilan el proyecto.

## 5. Ejecución del backend

```
cd consware-reembolsos/backend/Consware.Reimbursements.Api
dotnet run --urls http://localhost:5000
```

La API queda en `http://localhost:5000/api/reimbursements`.

## 6. Ejecución de Flutter

```
cd consware-reembolsos/mobile
flutter pub get
flutter run
```

- La URL la decide `lib/config/api_config.dart`: `10.0.2.2` en el emulador Android y `localhost` en escritorio.
- Celular físico: sustituir el host por la IP de LAN del equipo y revisar el firewall.
- En Android se habilita `android:usesCleartextTraffic="true"` en `AndroidManifest.xml` porque la API local usa HTTP.
- Pruebas de integración: `flutter test integration_test`.

## 7. Ejecución de Angular

```
cd consware-reembolsos/web
npm install
npm start          # http://localhost:4200
npm test           # 10 tests unitarios (Vitest)
npm run build      # build de producción
```

- El panel arranca filtrando por **Pendientes**; se puede cambiar a Todos, Aprobadas o Rechazadas y buscar por empleado.
- CORS: la API declara el origen `http://localhost:4200` en la policy `AngularLocal` (`Program.cs`). Si el panel corre en otro puerto, hay que añadirlo a `WithOrigins`.
- Si la API está apagada, el panel muestra un mensaje con la dirección a revisar en lugar de fallar en blanco.

## 8. Rutas HTTP y reglas de negocio

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/reimbursements` | Crea una solicitud (201) |
| GET | `/api/reimbursements?status=&employeeName=` | Lista con filtros opcionales |
| GET | `/api/reimbursements/{id}` | Consulta por id (404 si no existe) |
| PATCH | `/api/reimbursements/{id}/approve` | Aprueba una solicitud `Pending` |
| PATCH | `/api/reimbursements/{id}/reject` | Rechaza con `{"reason": "..."}` |

Códigos de error: 400 (validación o motivo vacío), 404 (no existe), 409 (la solicitud ya fue decidida).

Validaciones al crear: monto mayor que 0, categoría y descripción no vacías.

Las fechas se devuelven en UTC con la marca `Z` (`2026-11-02T15:21:52.3246162Z`), para que cada cliente las convierta a su zona horaria.

## 9. Pruebas realizadas

### Ejecutadas el 2026-11-02

**Matriz de la guía (T01–T16), automatizada:**

```
powershell -ExecutionPolicy Bypass -File consware-reembolsos/scripts/test-api.ps1
```

Resultado: **Total 18 | PASS 18 | FAIL 0** (código de salida 0).

| Bloque | Pruebas | Resultado |
|---|---|---|
| Creación | T01 100000 → Approved, T02 500000 → Approved, T03 500001 → Pending | PASS |
| Validación | T04 monto 0, T05 monto -1, T06 descripción `   `, T07/T07b categoría vacía → 400 sin persistir | PASS |
| Consultas | T08 id inexistente 404, T09–T11 filtros por estado/empleado, T11b estado desconocido 400 | PASS |
| Decisiones | T12 aprobar 200, T13 rechazar con motivo 200, T14 motivo en blanco 400 y sigue Pending, T15/T16 409 | PASS |

**Flujo end-to-end de la guía §10:** POST 650.000 → `Pending` → `PATCH reject` con motivo → `Rejected` con motivo → `GET` devuelve lo mismo (persistencia en SQL Server) → `PATCH approve` sobre la rechazada responde 409.

**Fechas UTC (bug corregido):** antes del arreglo, `GET` devolvía `"createdAtUtc":"2026-10-31T22:35:38.7305391"` sin `Z`, y Flutter lo interpretaba como hora local (5 horas de desfase en Colombia). Ahora todos los registros responden con `Z` (0 casos sin `Z` sobre los 21 registros). Comprobado también en el navegador: `15:21Z` se muestra como `10:21 a. m.`.

**Panel Angular:**

- `npm run build` sin errores.
- `npm test`: **10/10 PASS** — carga inicial con filtro `Pending`, filtro `Todos` sin parámetro `status`, búsqueda por empleado, bloqueo del motivo vacío en la UI sin llamar a la API (T19), `PATCH reject` con el motivo correcto, confirmación antes de aprobar, mensaje claro con la API apagada y manejo del 409 recargando la tabla.
- Render real con Chrome headless sobre `http://localhost:4200`: tabla con 5 pendientes, chips de filtro, sin banner de error.
- CORS verificado con `Origin: http://localhost:4200` en `OPTIONS`/`GET`/`PATCH` (`Access-Control-Allow-Origin: http://localhost:4200`).

**Persistencia tras reiniciar la API:** los registros seguían disponibles después de detener y volver a levantar el backend.

### Pendiente de verificar en el navegador

- [ ] T17 Flutter con la API apagada (mensaje de error y reintento)
- [ ] T18 Flutter muestra el registro nuevo después del POST
- [ ] Recorrido manual completo del panel Angular (aprobar/rechazar con clic) y de Flutter en el emulador
- [ ] T20 reiniciar API y comprobar los datos desde los dos clientes

## 10. Decisiones técnicas

- **SQL Server** porque ya estaba instalado y cumple el requisito de base SQL real.
- **Una sola tabla** (`ReimbursementRequests`): el empleado se identifica por nombre, sin login ni tabla de usuarios.
- **Reglas en el servicio**, no en el controller ni en los clientes, para que la política de 500.000 viva en un solo lugar.
- **Estados como texto** (`Pending`, `Approved`, `Rejected`) para que el JSON y la base sean legibles.
- **Monolito pequeño**: un solo dominio y poco tiempo no justifican más proyectos o servicios.
- **Migraciones EF Core** como única fuente del esquema.
- **Fechas UTC con `Z`**: EF Core materializa `datetime2` con `Kind = Unspecified` y System.Text.Json no escribe el sufijo `Z`, así que el cliente las tomaba como hora local. En `Data/AppDbContext.cs` se fija `Kind = DateTimeKind.Utc` con un `ValueConverter` en la lectura; no cambia el valor ni el tipo de columna, por lo que **no requiere migración**.
- **Panel Angular sin librerías de UI extra**: CSS propio para centrar el esfuerzo en que los botones realmente actualicen SQL Server.

## 11. Fuera de alcance

Autenticación, administración de empleados, carga de recibos, auditoría, concurrencia con `rowversion`, Docker, nube y notificaciones.

Cómo se abordaría: añadir identidad (por ejemplo Entra ID o JWT), una tabla de usuarios con roles `employee`/`approver`, un `rowversion` por fila para concurrencia y contenedores con Docker Compose (API + SQL Server).

## 12. Uso de IA

- **Herramienta:** Claude (Anthropic), dentro del agente OpenCode.
- **Tareas asistidas:** planificación del orden de trabajo, borrador del modelo, servicio, controller y configuración de la API, borrador de la app Flutter, diagnóstico de errores de compilación y ejecución, implementación del panel Angular y de sus tests, y redacción de este README.
- **Verificación:** el código se compiló y se ejecutó localmente; la matriz T01–T16 se corrió contra la API real (18/18), el flujo end-to-end se repitió contra SQL Server, el panel Angular se construyó y se probó (10/10) y se comprobó el render en un navegador headless. El fix de fechas se validó con la API devolviendo `Z` y con la hora local correcta en el navegador.
- **Comprensión:** entiendo el código que entrego. La política de 500.000 COP vive en `ReimbursementService` y no en el controller ni en Flutter, para que exista un solo lugar donde cambiarla y los clientes no puedan saltársela. Al crear una solicitud, el servicio valida los datos (monto mayor que 0, categoría y descripción no vacías) y decide el estado: si el monto es menor o igual a 500.000 queda `Approved` con fecha de decisión, y si es mayor queda `Pending`. Para aprobar o rechazar, el servicio primero comprueba que el estado sea `Pending`; si no lo es, lanza una excepción que el controller traduce a 409, y así una solicitud decidida nunca vuelve a cambiar. El rechazo además exige un motivo no vacío, y si falta responde 400. En el cliente Angular, el motivo vacío también se bloquea antes de hacer la petición. El controller solo traduce excepciones a códigos HTTP (400, 404, 409). Usé la IA como apoyo para armar los borradores y resolver errores, pero ejecuté el código y verifiqué los resultados contra la API y la base de datos reales.
