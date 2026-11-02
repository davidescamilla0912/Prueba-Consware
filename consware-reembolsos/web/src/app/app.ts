import { Component, OnDestroy, OnInit, signal } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { Subject, Subscription, debounceTime, distinctUntilChanged } from 'rxjs';
import { Reimbursement, ReimbursementStatus } from './models/reimbursement';
import { ReimbursementService } from './services/reimbursement.service';

type StatusFilter = ReimbursementStatus | null;

/**
 * Panel del aprobador: tabla de solicitudes con filtro por estado y búsqueda
 * por empleado, más las decisiones de aprobar y rechazar con motivo.
 * Toda la lógica de negocio vive en la API; aquí sólo se pinta y se llama.
 */
@Component({
  selector: 'app-root',
  styleUrl: './app.scss',
  templateUrl: './app.html',
})
export class App implements OnInit, OnDestroy {
  readonly filters: { label: string; value: StatusFilter }[] = [
    { label: 'Todos', value: null },
    { label: 'Pendientes', value: 'Pending' },
    { label: 'Aprobadas', value: 'Approved' },
    { label: 'Rechazadas', value: 'Rejected' },
  ];

  readonly items = signal<Reimbursement[]>([]);
  readonly loading = signal(false);
  readonly saving = signal(false);
  readonly error = signal<string | null>(null);
  readonly notice = signal<string | null>(null);

  readonly statusFilter = signal<StatusFilter>('Pending');
  readonly employeeInput = signal('');

  readonly detail = signal<Reimbursement | null>(null);
  readonly detailLoading = signal(false);
  readonly detailError = signal<string | null>(null);

  readonly rejectTarget = signal<Reimbursement | null>(null);
  readonly rejectReason = signal('');
  readonly rejectError = signal<string | null>(null);

  readonly employeeFilter = signal('');
  private readonly searchInput = new Subject<string>();
  private readonly subscription = new Subscription();

  private readonly amountFormatter = new Intl.NumberFormat('es-CO', {
    style: 'currency',
    currency: 'COP',
    maximumFractionDigits: 0,
  });

  /** Los datos llegan en UTC (con Z); se muestran en la hora local de Colombia. */
  private readonly dateFormatter = new Intl.DateTimeFormat('es-CO', {
    dateStyle: 'short',
    timeStyle: 'short',
    timeZone: 'America/Bogota',
  });

  constructor(private readonly service: ReimbursementService) {}

  ngOnInit(): void {
    this.subscription.add(
      this.searchInput
        .pipe(debounceTime(300), distinctUntilChanged())
        .subscribe((value) => {
          this.employeeFilter.set(value.trim());
          this.load();
        }),
    );
    this.load();
  }

  ngOnDestroy(): void {
    this.subscription.unsubscribe();
  }

  // --- Consulta -------------------------------------------------------------

  load(): void {
    this.loading.set(true);
    this.error.set(null);
    this.service.getAll(this.statusFilter(), this.employeeFilter()).subscribe({
      next: (data) => {
        this.items.set(data);
        this.loading.set(false);
      },
      error: (err) => {
        this.items.set([]);
        this.error.set(this.messageFor(err));
        this.loading.set(false);
      },
    });
  }

  setFilter(value: StatusFilter): void {
    if (this.statusFilter() === value) return;
    this.statusFilter.set(value);
    this.notice.set(null);
    this.load();
  }

  onSearchInput(event: Event): void {
    const value = (event.target as HTMLInputElement).value;
    this.employeeInput.set(value);
    this.searchInput.next(value);
  }

  clearSearch(): void {
    this.employeeInput.set('');
    this.searchInput.next('');
  }

  // --- Detalle --------------------------------------------------------------

  openDetail(item: Reimbursement): void {
    this.detail.set(item);
    this.detailError.set(null);
    this.detailLoading.set(true);
    this.service.getById(item.id).subscribe({
      next: (fresh) => {
        if (this.detail()?.id === item.id) this.detail.set(fresh);
        this.detailLoading.set(false);
      },
      error: (err) => {
        this.detailLoading.set(false);
        if (err instanceof HttpErrorResponse && err.status === 404) {
          this.closeDetail();
          this.notice.set(`La solicitud #${item.id} ya no existe.`);
          this.load();
          return;
        }
        this.detailError.set(this.messageFor(err));
      },
    });
  }

  closeDetail(): void {
    this.detail.set(null);
    this.detailError.set(null);
  }

  // --- Decisiones -----------------------------------------------------------

  approve(item: Reimbursement): void {
    const question =
      `¿Aprobar la solicitud #${item.id} de ${item.employeeName} ` +
      `por ${this.formatAmount(item.amount)}?`;
    if (!window.confirm(question)) return;

    this.saving.set(true);
    this.error.set(null);
    this.notice.set(null);
    this.service.approve(item.id).subscribe({
      next: (updated) => {
        this.saving.set(false);
        this.notice.set(`Solicitud #${item.id} aprobada.`);
        if (this.detail()?.id === item.id) this.detail.set(updated);
        this.load();
      },
      error: (err) => this.onDecisionError(err, item),
    });
  }

  openReject(item: Reimbursement): void {
    this.rejectTarget.set(item);
    this.rejectReason.set('');
    this.rejectError.set(null);
  }

  closeReject(): void {
    this.rejectTarget.set(null);
    this.rejectReason.set('');
    this.rejectError.set(null);
  }

  onReasonInput(event: Event): void {
    this.rejectReason.set((event.target as HTMLTextAreaElement).value);
  }

  /** T19: la UI no envía un motivo vacío; la API también lo valida. */
  submitReject(): void {
    const target = this.rejectTarget();
    if (!target) return;

    const reason = this.rejectReason().trim();
    if (!reason) {
      this.rejectError.set('Escribe un motivo de rechazo.');
      return;
    }

    this.saving.set(true);
    this.rejectError.set(null);
    this.service.reject(target.id, reason).subscribe({
      next: (updated) => {
        this.saving.set(false);
        this.closeReject();
        this.notice.set(`Solicitud #${target.id} rechazada.`);
        if (this.detail()?.id === target.id) this.detail.set(updated);
        this.load();
      },
      error: (err) => {
        this.saving.set(false);
        const message = this.messageFor(err);
        // 409/404: la decisión cambió en el servidor; se cierra y se recarga.
        if (err instanceof HttpErrorResponse && (err.status === 409 || err.status === 404)) {
          this.closeReject();
          this.load();
          this.error.set(message);
          return;
        }
        // 400 u otro fallo: se queda en el modal para corregir el motivo.
        this.rejectError.set(message);
      },
    });
  }

  dismissNotice(): void {
    this.notice.set(null);
  }

  dismissError(): void {
    this.error.set(null);
  }

  // --- Presentación ---------------------------------------------------------

  formatAmount(amount: number): string {
    return this.amountFormatter.format(amount);
  }

  formatDate(iso: string): string {
    return this.dateFormatter.format(new Date(iso));
  }

  statusLabel(status: ReimbursementStatus): string {
    switch (status) {
      case 'Pending':
        return 'Pendiente';
      case 'Approved':
        return 'Aprobada';
      case 'Rejected':
        return 'Rechazada';
    }
  }

  shortText(value: string, limit = 48): string {
    return value.length > limit ? `${value.slice(0, limit)}…` : value;
  }

  // --- Errores --------------------------------------------------------------

  private onDecisionError(err: unknown, item: Reimbursement): void {
    this.saving.set(false);
    const message = this.messageFor(err);
    if (err instanceof HttpErrorResponse && (err.status === 409 || err.status === 404)) {
      // Ya fue decidida (o no existe): recargar y avisar. load() limpia el
      // banner, así que el mensaje se fija después de disparar la recarga.
      this.load();
      this.error.set(message);
      return;
    }
    this.error.set(message);
  }

  private messageFor(err: unknown): string {
    if (!(err instanceof HttpErrorResponse)) {
      return 'Error inesperado al contactar la API.';
    }
    if (err.status === 0) {
      return 'No se pudo conectar con http://localhost:5000. Revisa que la API esté corriendo.';
    }
    if (err.status === 409) {
      return 'La solicitud ya fue decidida y no puede cambiar de estado. Se recargó la tabla.';
    }
    if (err.status === 404) {
      return 'La solicitud no existe.';
    }
    const body = err.error as { message?: string } | null;
    if (body && typeof body.message === 'string' && body.message) {
      return body.message;
    }
    return `Respuesta inesperada del servidor (HTTP ${err.status}).`;
  }
}
