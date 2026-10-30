# Sistema de reembolso de gastos

Prueba técnica Fullstack de Consware. Permite que un empleado registre un gasto y consulte su estado, con una API central que aplica la política de aprobación.

## 1. Descripción y alcance

- Un empleado crea una solicitud de reembolso (monto, categoría, descripción) y consulta sus solicitudes.
- La API decide el estado al crear la solicitud:
  - Monto menor o igual a 500.000 COP: se aprueba automáticamente.
  - Monto mayor a 500.000 COP: queda en `Pending`.
- Una solicitud `Pending` puede aprobarse o rechazarse. El rechazo exige un motivo no vacío.
- Una solicitud aprobada o rechazada no vuelve a cambiar de estado.
- Los datos se guardan en SQL Server.

### Estado actual

| Componente | Estado |
|---|---|
| API REST (ASP.NET Core + SQL Server) | Implementada. Reglas de 500000 y 500001 verificadas |
| App Flutter (empleado) | [ ] Código escrito, pendiente de ejecutar y verificar |
| Panel Angular (aprobador) | [ ] No implementado (fuera de alcance por tiempo) |

## 2. Tecnologías

- ASP.NET Core (.NET 9), Entity Framework Core, SQL Server
- Flutter (paquete `http`)
- Angular (no implementado)

## 3. Requisitos previos

- .NET SDK 9 y la herramienta `dotnet-ef` (`dotnet tool install --global dotnet-ef`)
- SQL Server accesible (en desarrollo: instancia local `JEREMY\MSSQLSERVER2026`)
- Flutter SDK y un emulador Android (o Chrome)

## 4. Configuración de SQL Server

El connection string está en `backend/api/appsettings.json`, con autenticación integrada de Windows:

```
Server=JEREMY\MSSQLSERVER2026;Database=ConswareReembolsosDB;Trusted_Connection=True;TrustServerCertificate=True
```

El nombre de instancia es local. En otro equipo hay que cambiar `Server=` por el nombre de su instancia.

El esquema se crea con migraciones de EF Core, desde `backend/api`:

```
dotnet ef migrations add Initial
dotnet ef database update
```

(Detener la API antes de ejecutar estos comandos, porque recompilan el proyecto.)

## 5. Ejecución del backend

```
cd backend/api
dotnet run --urls http://localhost:5000
```

La API queda en `http://localhost:5000/api/reimbursements`.

## 6. Ejecución de Flutter

```
cd mobile
flutter pub get
flutter run
```

- Emulador Android: `baseUrl` usa `http://10.0.2.2:5000/api/reimbursements`.
- Chrome: cambiar `baseUrl` a `http://localhost:5000/api/reimbursements` y ejecutar `flutter run -d chrome`.
- En Android se habilita `android:usesCleartextTraffic="true"` en `AndroidManifest.xml` porque la API local usa HTTP.

## 7. Ejecución de Angular

No implementado en esta entrega.

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

## 9. Pruebas realizadas

Verificadas manualmente contra la API real:

- Monto 500000 queda `Approved`.
- Monto 500001 queda `Pending`.
- GET lista las solicitudes con el estado como texto.
- Los datos se leen desde SQL Server.

Pendientes de verificar: [ ] montos 0 y -1 (400), [ ] descripción y categoría vacías (400), [ ] id inexistente (404), [ ] filtros por estado y empleado, [ ] aprobar y rechazar con motivo (200), [ ] rechazo sin motivo (400), [ ] decidir una solicitud ya decidida (409), [ ] persistencia tras reiniciar la API, [ ] flujo completo desde Flutter, [ ] Flutter con la API apagada.

## 10. Decisiones técnicas

- **SQL Server** porque ya estaba instalado y cumple el requisito de base SQL real.
- **Una sola tabla** (`ReimbursementRequests`): el empleado se identifica por nombre, sin login ni tabla de usuarios.
- **Reglas en el servicio**, no en el controller ni en los clientes, para que la política de 500.000 viva en un solo lugar.
- **Estados como texto** (`Pending`, `Approved`, `Rejected`) para que el JSON y la base sean legibles.
- **Monolito pequeño**: un solo dominio y poco tiempo no justifican más proyectos o servicios.
- **Migraciones EF Core** como única fuente del esquema.

## 11. Fuera de alcance

Autenticación, administración de empleados, carga de recibos, auditoría, Docker, nube, notificaciones y el panel Angular.

## 12. Uso de IA

- **Herramienta:** Claude (Anthropic).
- **Tareas asistidas:** planificación del orden de trabajo, borrador del modelo, servicio, controller y configuración de la API, borrador de la app Flutter, y diagnóstico de errores de compilación y ejecución.
- **Verificación:** el código se compiló y se ejecutó localmente, y las reglas de 500000 y 500001 se comprobaron contra la API y la base real.
- **Comprensión:** Entiendo el código que entrego. La política de 500.000 COP vive en `ReimbursementService` y no en el controller ni en Flutter, para que exista un solo lugar donde cambiarla y los clientes no puedan saltársela. Al crear una solicitud, el servicio valida los datos (monto mayor que 0, categoría y descripción no vacías) y decide el estado: si el monto es menor o igual a 500.000 queda `Approved` con fecha de decisión, y si es mayor queda `Pending`. Para aprobar o rechazar, el servicio primero comprueba que el estado sea `Pending`; si no lo es, lanza una excepción que el controller traduce a 409, y así una solicitud decidida nunca vuelve a cambiar. El rechazo además exige un motivo no vacío, y si falta responde 400. El controller solo traduce excepciones a códigos HTTP (400, 404, 409). Usé la IA como apoyo para armar el borrador y resolver errores, pero ejecuté el código y verifiqué las reglas contra la API y la base de datos real.
