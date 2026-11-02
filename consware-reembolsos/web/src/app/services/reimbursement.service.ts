import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Reimbursement, ReimbursementStatus } from '../models/reimbursement';

/** Cliente HTTP de la única fuente de verdad: la API REST. */
@Injectable({ providedIn: 'root' })
export class ReimbursementService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = 'http://localhost:5000/api/reimbursements';

  getAll(status?: ReimbursementStatus | null, employeeName?: string): Observable<Reimbursement[]> {
    let params = new HttpParams();
    if (status) params = params.set('status', status);
    if (employeeName && employeeName.trim()) params = params.set('employeeName', employeeName.trim());
    return this.http.get<Reimbursement[]>(this.baseUrl, { params });
  }

  getById(id: number): Observable<Reimbursement> {
    return this.http.get<Reimbursement>(`${this.baseUrl}/${id}`);
  }

  approve(id: number): Observable<Reimbursement> {
    return this.http.patch<Reimbursement>(`${this.baseUrl}/${id}/approve`, null);
  }

  reject(id: number, reason: string): Observable<Reimbursement> {
    return this.http.patch<Reimbursement>(`${this.baseUrl}/${id}/reject`, { reason });
  }
}
