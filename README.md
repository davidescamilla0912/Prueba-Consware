# Sistema de reembolso de gastos

Prueba técnica Fullstack de Consware. Un empleado registra un gasto desde una app Flutter y consulta su estado. Un aprobador revisa las solicitudes desde un panel Angular y las aprueba o rechaza con motivo. Una única API ASP.NET Core aplica la política de aprobación y guarda todo en SQL Server.

```
Flutter (emulador Android) ──┐
                             ├──► API ASP.NET Core (:5000) ──► SQL Server (ConswareReembolsosDB)
Angular (navegador :4200) ───┘
```

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
| App Flutter (empleado) | Implementada para **emulador Android**. 5/5 tests unitarios y prueba de integración en `mobile/integration_test/` |
| Panel Angular (aprobador) | Implementado: build OK, **10/10 tests**, render y CORS verificados |

### Estructura del repositorio

```
consware-reembolsos/
├── backend/Consware.Reimbursements.Api/   API: Controllers, Services, DTOs, Data, Models, Migrations
├── mobile/                                App Flutter del empleado (lib/, test/, integration_test/, android/)
├── web/                                   Panel Angular del aprobador (src/app/)
└── scripts/test-api.ps1                   Matriz de pruebas T01–T16 contra la API
```

## 2. Tecnologías

- ASP.NET Core (.NET 9) con Entity Framework Core 9 (proveedor SQL Server, Code-First con migraciones)
- SQL Server (Express, Developer o LocalDB)
- Flutter 3 / Dart 3 con el paquete `http`; estado con `setState`
- Angular 22 (standalone, `provideHttpClient`, SCSS) con Vitest

## 3. Requisitos previos (para correrlo en otro equipo)

Instalar en el equipo nuevo:

| Herramienta | Versión | Comprobar con |
|---|---|---|
| .NET SDK | 9.x | `dotnet --version` |
| Herramienta EF Core | 9.x | `dotnet ef --version` |
| SQL Server | Express, Developer o LocalDB | SSMS o `sqlcmd -L` |
| Flutter SDK | 3.x estable | `flutter doctor` |
| Android Studio + un emulador Android (AVD) | Android SDK con licencias aceptadas | `flutter emulators` |
| Node.js con npm | 20 o superior | `node -v` / `npm -v` |
| Git | cualquiera | `git --version` |

Instalar la herramienta de migraciones (si `dotnet ef` no existe):

```
dotnet tool install --global dotnet-ef --version 9.*
```

Preparar Android:

```
flutter doctor --android-licenses      # aceptar licencias
flutter doctor                          # debe mostrar Android toolchain en verde
```

En Android Studio: **Device Manager → Create Device** (por ejemplo, Pixel con una imagen de sistema reciente) para tener un emulador.

Clonar el repositorio:

```
git clone <url-del-repositorio>
cd <carpeta-del-repositorio>
```

## 4. Configuración de SQL Server

El connection string está en `consware-reembolsos/backend/Consware.Reimbursements.Api/appsettings.json` y usa autenticación integrada de Windows:

```json
"DefaultConnection": "Server=localhost\\SQLEXPRESS;Database=ConswareReembolsosDB;Trusted_Connection=True;TrustServerCertificate=True;"
```

`localhost\SQLEXPRESS` es la instancia del equipo de desarrollo. **En otro equipo hay que cambiar `Server=`** por la instancia local:

| Instalación | Valor de `Server=` en el JSON |
|---|---|
| SQL Server Express (instancia por defecto del instalador) | `localhost\\SQLEXPRESS` |
| SQL Server Developer/Standard (instancia predeterminada) | `localhost` |
| Instancia con nombre | `NOMBRE-EQUIPO\\NOMBRE-INSTANCIA` (el que aparece en SSMS al conectar) |
| LocalDB (viene con Visual Studio) | `(localdb)\\MSSQLLocalDB` |

Notas:

- En JSON la barra invertida va doble (`\\`).
- `Trusted_Connection=True` usa el usuario de Windows que ejecuta la API: ese usuario necesita permiso para crear la base (o un administrador la crea vacía desde SSMS antes de migrar).
- `TrustServerCertificate=True` es solo para desarrollo local.
- No se guardan usuarios ni contraseñas en el repositorio.

Crear la base y la tabla con la migración ya incluida (`Migrations/20261031142239_InitialCreate`):

```
cd consware-reembolsos/backend/Consware.Reimbursements.Api
dotnet restore
dotnet ef database update
```

Esto crea `ConswareReembolsosDB`, la tabla `dbo.ReimbursementRequests` con sus restricciones `CHECK` (monto > 0, estado válido, motivo obligatorio si es `Rejected`) e índices. No hay que ejecutar scripts SQL manuales. Solo se necesita `dotnet ef migrations add <Nombre>` si cambia el modelo. Detener la API antes de estos comandos, porque recompilan el proyecto.

Comprobar en SSMS:

```sql
USE ConswareReembolsosDB;
SELECT TOP (100) * FROM dbo.ReimbursementRequests ORDER BY Id DESC;
```

## 5. Ejecución del backend

```
cd consware-reembolsos/backend/Consware.Reimbursements.Api
dotnet restore
dotnet ef database update
dotnet run
```

`dotnet run` usa el perfil de `Properties/launchSettings.json` y deja la API en **`http://localhost:5000/api/reimbursements`**. Abrir esa URL en el navegador debe devolver `[]` o la lista de solicitudes.

- El emulador Android llega a esta API por `10.0.2.2`, que apunta al `localhost` del equipo, así que no hace falta configuración adicional.
- Solo para un celular físico en la misma red: `dotnet run --urls http://0.0.0.0:5000` y permitir el puerto 5000 en el Firewall de Windows.
- Dejar la API encendida mientras se usan Flutter y Angular.
- `Consware.Reimbursements.Api.http` contiene peticiones de ejemplo para VS Code / Visual Studio.

## 6. Ejecución de Flutter (emulador Android)

La app del empleado se ejecuta en un **emulador de Android**.

```
cd consware-reembolsos/mobile
flutter pub get
flutter emulators                         # lista los emuladores creados
flutter emulators --launch <id_emulador>  # o iniciarlo desde Android Studio
flutter devices                           # debe aparecer emulator-5554 (o similar)
flutter run -d emulator-5554
```

**Alternativa: iniciar el emulador directamente desde PowerShell** (es lo que se usó en desarrollo, con un AVD llamado `consware`):

```powershell
Start-Process "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -ArgumentList '-avd','consware','-no-boot-anim','-no-metrics'
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices
```

Qué ajustar en otro equipo:

- **Nombre del AVD:** `consware` es el emulador creado en el equipo de desarrollo. Para ver los disponibles: `& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -list-avds` (o `flutter emulators`), y poner ese nombre después de `-avd`.
- **Ruta del SDK:** `%LOCALAPPDATA%\Android\Sdk` es la ubicación por defecto de Android Studio en Windows. Si se instaló en otro sitio, la ruta aparece en Android Studio → *Settings → Languages & Frameworks → Android SDK* (o en `flutter doctor -v`).
- `adb devices` debe listar `emulator-5554   device`. Si sale `offline`, esperar a que termine de arrancar y repetir. Después: `flutter run -d emulator-5554`.

- La URL de la API está en `lib/config/api_config.dart`: en Android usa `http://10.0.2.2:5000/api/reimbursements`. No hay que cambiarla para el emulador.
- Celular físico: sustituir `10.0.2.2` por la IP de LAN del equipo (ver `ipconfig`) e iniciar la API con `--urls http://0.0.0.0:5000`.
- El empleado está fijo como `Empleado Demo` (`ApiConfig.employeeName`); no hay login, como permite el enunciado.
- El permiso `INTERNET` está en `android/app/src/main/AndroidManifest.xml`; el tráfico HTTP sin cifrar se habilita **solo en debug** (`android/app/src/debug/AndroidManifest.xml`).
- Pruebas:

  ```
  flutter test                                       # 5 tests unitarios y de widget (sin red)
  flutter test integration_test -d emulator-5554     # flujo real contra la API (debe estar encendida)
  ```

## 7. Ejecución de Angular

```
cd consware-reembolsos/web
npm install
npm start          # http://localhost:4200 (o el siguiente puerto libre si está ocupado)
```

Abrir `http://localhost:4200`.

- El panel consume `http://localhost:5000/api/reimbursements` (`src/app/services/reimbursement.service.ts`).
- Arranca filtrando por **Pendientes**; se puede cambiar a Todos, Aprobadas o Rechazadas y buscar por empleado.
- Rechazar abre un cuadro que exige el motivo: con el texto vacío el botón queda deshabilitado y no se llama a la API.
- CORS: la policy `AngularLocal` (`Program.cs`) acepta **cualquier puerto** de `localhost` o `127.0.0.1`. `ng serve` cambia de puerto si el 4200 está ocupado, y el panel sigue funcionando sin tocar el backend. Fuera de localhost no se autoriza ningún origen.
- Si la API está apagada, el panel muestra un mensaje con la dirección a revisar en lugar de quedar en blanco.
- Otros comandos:

  ```
  npm test           # 10 tests unitarios (Vitest)
  npm run build      # build de producción en dist/
  ```

### Orden recomendado en un equipo nuevo

1. SQL Server encendido y `Server=` ajustado en `appsettings.json` (§4).
2. `dotnet ef database update` y `dotnet run` en el backend (§5).
3. `npm install` y `npm start` en `web/` (§7).
4. Emulador Android iniciado y `flutter run` en `mobile/` (§6).
5. Flujo de demostración: crear 650.000 en Flutter → aparece Pendiente → rechazarla en Angular con motivo → actualizar Flutter → se ve Rechazada con el motivo → reiniciar la API → los datos siguen.

### Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `SqlException` / `A network-related ... error` al migrar | Nombre de instancia incorrecto o servicio detenido | Copiar el nombre de servidor exacto de SSMS a `Server=`; iniciar el servicio `SQL Server (...)` |
| `Login failed` / `CREATE DATABASE permission denied` | El usuario de Windows no tiene permisos | Crear la base vacía `ConswareReembolsosDB` desde SSMS con una cuenta autorizada y repetir `dotnet ef database update` |
| `dotnet ef` no se reconoce | Falta la herramienta | `dotnet tool install --global dotnet-ef --version 9.*` y abrir una terminal nueva |
| `dotnet ef` falla con archivos bloqueados | La API está corriendo | Detener la API y repetir |
| Flutter: "No se pudo conectar con el servidor" | API apagada o puerto distinto de 5000 | Iniciar el backend; comprobar `http://localhost:5000/api/reimbursements` en el navegador del equipo |
| `flutter devices` no muestra el emulador | Emulador apagado o licencias pendientes | `flutter emulators --launch <id>`; `flutter doctor --android-licenses` |
| Angular: error de CORS en la consola | El panel no corre en localhost | Abrirlo desde `http://localhost:<puerto>` |

## 8. Rutas HTTP y reglas de negocio

**Regla central:** monto ≤ 500.000 COP → `Approved` automático (con fecha de decisión); monto > 500.000 COP → `Pending`. 500.000 exactos se aprueban; 500.001 queda pendiente.

| Método | Ruta | Descripción | Respuestas |
|---|---|---|---|
| POST | `/api/reimbursements` | Crea una solicitud | 201 (con `Location`), 400 |
| GET | `/api/reimbursements?status=&employeeName=` | Lista con filtros opcionales y combinables | 200 (`[]` si no hay), 400 si el estado no existe |
| GET | `/api/reimbursements/{id}` | Consulta por id | 200, 404 |
| PATCH | `/api/reimbursements/{id}/approve` | Aprueba una solicitud `Pending` | 200, 404, 409 |
| PATCH | `/api/reimbursements/{id}/reject` | Rechaza con `{"reason": "..."}` | 200, 400, 404, 409 |

- Validaciones al crear: nombre, categoría y descripción no vacíos ni solo espacios; monto mayor que 0.
- El rechazo exige un motivo no nulo, no vacío y no solo espacios (400).
- Aprobar o rechazar una solicitud ya decidida devuelve 409 y no cambia nada.
- Todos los errores tienen el mismo formato: `{"message": "..."}`, en español.
- Las fechas se devuelven en UTC con la marca `Z` (`2026-11-02T15:21:52.3246162Z`), para que cada cliente las convierta a su zona horaria.

## 9. Pruebas realizadas

### Ejecutadas el 2026-11-02

**Matriz de la guía (T01–T16), automatizada** (con la API encendida):

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

**Formato de errores uniforme:** con campos ausentes o nulos (`POST` sin `category`, `"description": null`, `PATCH reject` con `{}` o `{"reason": null}`) la API responde 400 con `{"message": "..."}` en español, igual que con textos vacíos o solo espacios.

**Flujo end-to-end de la guía §10:** POST 650.000 → `Pending` → `PATCH reject` con motivo → `Rejected` con motivo → `GET` devuelve lo mismo (persistencia en SQL Server) → `PATCH approve` sobre la rechazada responde 409.

**Fechas UTC (bug corregido):** antes del arreglo, `GET` devolvía `"createdAtUtc":"2026-10-31T22:35:38.7305391"` sin `Z`, y Flutter lo interpretaba como hora local (5 horas de desfase en Colombia). Ahora todos los registros responden con `Z`. Comprobado también en el navegador: `15:21Z` se muestra como `10:21 a. m.`.

**Flutter:** `flutter analyze` sin problemas; `flutter test` 5/5 PASS (lectura del JSON, formato de montos, traducción de estados, formulario que no envía campos vacíos ni montos ≤ 0).

**Panel Angular:**

- `npm run build` sin errores.
- `npm test`: **10/10 PASS**. Cubre la carga inicial con filtro `Pending`, el filtro `Todos` sin parámetro `status`, la búsqueda por empleado, el bloqueo del motivo vacío en la UI sin llamar a la API (T19), el `PATCH reject` con el motivo correcto, la confirmación antes de aprobar, el mensaje claro con la API apagada y el manejo del 409 recargando la tabla.
- Render real con Chrome headless sobre `http://localhost:4200`: tabla con pendientes, chips de filtro y ningún banner de error.
- CORS verificado con `Origin: http://localhost:4200` y `http://localhost:49718` en `OPTIONS`/`GET`/`PATCH`; `http://evil.example.com` queda sin `Access-Control-Allow-Origin`.

**Persistencia tras reiniciar la API:** los registros seguían disponibles después de detener y volver a levantar el backend.

### Pendiente de verificar manualmente

- [ ] T17 Flutter en el emulador con la API apagada (mensaje de error y botón Reintentar)
- [ ] T18 Flutter muestra el registro nuevo después del POST (cubierto por `integration_test/app_test.dart`; falta registrar su ejecución)
- [ ] Recorrido manual completo del panel Angular (aprobar/rechazar con clic) y de Flutter en el emulador
- [ ] T20 reiniciar la API y comprobar los datos desde los dos clientes

## 10. Decisiones técnicas

- **SQL Server** porque ya estaba instalado y cumple el requisito de base SQL real.
- **Un backend y dos clientes:** Flutter (empleado) y Angular (aprobador) consumen la misma API, que es la única fuente de verdad. Ningún cliente decide estados ni accede a SQL Server.
- **Una sola tabla** (`ReimbursementRequests`): el empleado se identifica por nombre, sin login ni tabla de usuarios.
- **Reglas en el servicio**, no en el controller ni en los clientes, para que la política de 500.000 viva en un solo lugar.
- **DTOs con textos anulables:** así `[ApiController]` no responde por su cuenta con un `[Required]` implícito (en inglés y en otro formato), y el servicio valida con `string.IsNullOrWhiteSpace` devolviendo siempre `{"message": "..."}`.
- **Estados como texto** (`Pending`, `Approved`, `Rejected`) para que el JSON y la base sean legibles.
- **Monolito pequeño:** un solo dominio y poco tiempo no justifican más proyectos o servicios.
- **Migraciones EF Core** como única fuente del esquema, con restricciones `CHECK` como defensa adicional en la base.
- **Fechas UTC con `Z`:** EF Core materializa `datetime2` con `Kind = Unspecified` y System.Text.Json no escribe el sufijo `Z`, así que el cliente las tomaba como hora local. En `Data/AppDbContext.cs` se fija `Kind = DateTimeKind.Utc` con un `ValueConverter` en la lectura. No cambia el valor ni el tipo de columna, por lo que **no requiere migración**.
- **Flutter solo para Android:** el proyecto conserva únicamente las plataformas `android/` (objetivo de la prueba) y `windows/`; se eliminaron `ios/`, `linux/`, `macos/` y `web/`, que no se usan.
- **`setState` en Flutter y signals en Angular:** dos pantallas no justifican BLoC, Riverpod ni NgRx.
- **Panel Angular sin librerías de UI extra:** CSS propio para centrar el esfuerzo en que los botones realmente actualicen SQL Server.

## 11. Fuera de alcance

Autenticación, administración de empleados, carga de recibos, auditoría, concurrencia con `rowversion`, Docker, nube y notificaciones.

Cómo se abordaría: añadir identidad (por ejemplo Entra ID o JWT), una tabla de usuarios con roles `employee`/`approver`, un `rowversion` por fila para concurrencia y contenedores con Docker Compose (API + SQL Server).

## 12. Uso de IA

- **Herramientas:** Claude (Anthropic), usado dentro del agente OpenCode durante el desarrollo y con Claude Code para la auditoría final contra la guía técnica.
- **Tareas asistidas:** planificación del orden de trabajo, borrador del modelo, servicio, controller y configuración de la API, borrador de la app Flutter, diagnóstico de errores de compilación y ejecución, implementación del panel Angular y de sus tests, auditoría de cumplimiento (formato uniforme de errores, limpieza de archivos generados que no se usan) y redacción de este README.
- **Verificación:** el código se compiló y se ejecutó localmente. La matriz T01–T16 se corrió contra la API real (18/18), el flujo end-to-end se repitió contra SQL Server, el panel Angular se construyó y se probó (10/10), Flutter pasó `flutter analyze` y `flutter test` (5/5), y se comprobó el render en un navegador headless. El fix de fechas se validó con la API devolviendo `Z` y con la hora local correcta en el navegador.
- **Comprensión:** entiendo el código que entrego. La política de 500.000 COP vive en `ReimbursementService` y no en el controller ni en Flutter, para que exista un solo lugar donde cambiarla y los clientes no puedan saltársela. Al crear una solicitud, el servicio valida los datos (monto mayor que 0, nombre, categoría y descripción no vacíos) y decide el estado: si el monto es menor o igual a 500.000 queda `Approved` con fecha de decisión, y si es mayor queda `Pending`. Para aprobar o rechazar, el servicio primero comprueba que el estado sea `Pending`; si no lo es, lanza una excepción que el controller traduce a 409, y así una solicitud decidida nunca vuelve a cambiar. El rechazo además exige un motivo no vacío, y si falta responde 400. En el cliente Angular, el motivo vacío también se bloquea antes de hacer la petición. El controller solo traduce excepciones a códigos HTTP (400, 404, 409). Usé la IA como apoyo para armar los borradores y resolver errores, pero ejecuté el código y verifiqué los resultados contra la API y la base de datos reales.
