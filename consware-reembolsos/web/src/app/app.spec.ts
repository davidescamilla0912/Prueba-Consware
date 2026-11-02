import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { vi } from 'vitest';
import { App } from './app';
import { Reimbursement } from './models/reimbursement';

const API = 'http://localhost:5000/api/reimbursements';

function makeItem(overrides: Partial<Reimbursement> = {}): Reimbursement {
  return {
    id: 7,
    employeeName: 'Empleado Demo',
    amount: 650000,
    category: 'Transporte',
    description: 'Taxi a reunión',
    status: 'Pending',
    rejectionReason: null,
    createdAtUtc: '2026-11-02T15:21:52.3246162Z',
    decidedAtUtc: null,
    ...overrides,
  };
}

describe('App', () => {
  let httpMock: HttpTestingController;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [App],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    }).compileComponents();
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
    vi.restoreAllMocks();
  });

  /** Crea el componente y responde la carga inicial con la lista vacía. */
  function createLoaded() {
    const fixture = TestBed.createComponent(App);
    fixture.detectChanges();
    httpMock.expectOne((r) => r.url === API).flush([]);
    return fixture;
  }

  it('should create the app', () => {
    const fixture = TestBed.createComponent(App);
    expect(fixture.componentInstance).toBeTruthy();
    fixture.destroy();
  });

  it('should render the approver panel title', () => {
    const fixture = TestBed.createComponent(App);
    fixture.detectChanges();
    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('h1')?.textContent).toContain('Panel del aprobador');
    httpMock.expectOne((r) => r.url === API).flush([]);
    fixture.destroy();
  });

  it('should start filtered by Pending (filtro inicial de la guía)', () => {
    const fixture = TestBed.createComponent(App);
    fixture.detectChanges();

    const req = httpMock.expectOne(
      (r) => r.url === API && r.params.get('status') === 'Pending',
    );
    expect(req.request.method).toBe('GET');
    req.flush([makeItem()]);

    expect(fixture.componentInstance.statusFilter()).toBe('Pending');
    expect(fixture.componentInstance.items().length).toBe(1);
    fixture.destroy();
  });

  it('should drop the status param when showing all (filtro Todos)', () => {
    const fixture = createLoaded();

    fixture.componentInstance.setFilter(null);
    const req = httpMock.expectOne((r) => r.url === API && !r.params.has('status'));
    req.flush([]);

    expect(fixture.componentInstance.statusFilter()).toBeNull();
    fixture.destroy();
  });

  it('should send the employee filter as a query param', () => {
    const fixture = createLoaded();
    const app = fixture.componentInstance;

    app.employeeFilter.set('Empleado Demo');
    app.load();

    const req = httpMock.expectOne(
      (r) => r.url === API && r.params.get('employeeName') === 'Empleado Demo',
    );
    req.flush([]);
    fixture.destroy();
  });

  it('should block an empty rejection reason without calling the API (T19)', () => {
    const fixture = createLoaded();
    const app = fixture.componentInstance;

    app.openReject(makeItem());
    app.rejectReason.set('   ');
    app.submitReject();

    expect(app.rejectError()).toBe('Escribe un motivo de rechazo.');
    expect(app.rejectTarget()).not.toBeNull();
    // No hay peticiones pendientes: el envío se bloqueó en la UI.
    fixture.destroy();
  });

  it('should PATCH the reason when it is not empty', () => {
    const fixture = createLoaded();
    const app = fixture.componentInstance;

    app.openReject(makeItem({ id: 12 }));
    app.rejectReason.set('No cumple la politica de gastos.');
    app.submitReject();

    const req = httpMock.expectOne((r) => r.url === `${API}/12/reject`);
    expect(req.request.method).toBe('PATCH');
    expect(req.request.body).toEqual({ reason: 'No cumple la politica de gastos.' });
    req.flush(
      makeItem({ id: 12, status: 'Rejected', rejectionReason: 'No cumple la politica de gastos.' }),
    );

    // La respuesta dispara la recarga de la tabla.
    httpMock.expectOne((r) => r.url === API).flush([]);

    expect(app.rejectTarget()).toBeNull();
    expect(app.notice()).toContain('#12 rechazada');
    fixture.destroy();
  });

  it('should ask for confirmation before approving', () => {
    const fixture = createLoaded();
    const app = fixture.componentInstance;
    const confirmSpy = vi.spyOn(window, 'confirm');

    confirmSpy.mockReturnValue(false);
    app.approve(makeItem({ id: 3 }));
    expect(confirmSpy).toHaveBeenCalled();
    httpMock.expectNone((r) => r.url.includes('/approve'));

    confirmSpy.mockReturnValue(true);
    app.approve(makeItem({ id: 3 }));
    const req = httpMock.expectOne((r) => r.url === `${API}/3/approve`);
    expect(req.request.method).toBe('PATCH');
    req.flush(makeItem({ id: 3, status: 'Approved' }));
    httpMock.expectOne((r) => r.url === API).flush([]);

    expect(app.notice()).toContain('#3 aprobada');
    fixture.destroy();
  });

  it('should surface a friendly message when the API is unreachable', () => {
    const fixture = TestBed.createComponent(App);
    fixture.detectChanges();

    httpMock.expectOne((r) => r.url === API).error(new ProgressEvent('error'));

    expect(fixture.componentInstance.error()).toContain('http://localhost:5000');
    expect(fixture.componentInstance.items().length).toBe(0);
    fixture.destroy();
  });

  it('should explain a 409 and reload the table (solicitud ya decidida)', () => {
    const fixture = createLoaded();
    const app = fixture.componentInstance;

    vi.spyOn(window, 'confirm').mockReturnValue(true);
    app.approve(makeItem({ id: 3 }));
    const req = httpMock.expectOne((r) => r.url === `${API}/3/approve`);
    req.flush(
      { message: 'La solicitud ya fue decidida.' },
      { status: 409, statusText: 'Conflict' },
    );
    httpMock.expectOne((r) => r.url === API).flush([]);

    expect(app.error()).toContain('ya fue decidida');
    expect(app.saving()).toBe(false);
    fixture.destroy();
  });
});
