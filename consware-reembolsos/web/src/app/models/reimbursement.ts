export type ReimbursementStatus = 'Pending' | 'Approved' | 'Rejected';

export interface Reimbursement {
  id: number;
  employeeName: string;
  amount: number;
  category: string;
  description: string;
  status: ReimbursementStatus;
  rejectionReason: string | null;
  /** ISO 8601 en UTC. La API siempre lo devuelve con la marca Z. */
  createdAtUtc: string;
  decidedAtUtc: string | null;
}
