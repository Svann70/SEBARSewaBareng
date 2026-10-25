import { AppError } from '../../lib/errors.js';
import { idempotencyKeySchema, pageSchema, topupSchema, withdrawalSchema } from './wallet.schema.js';
import * as service from './wallet.service.js';

function walletDto(w) {
  return { balance: w.balance, held: w.held_balance, available: w.balance - w.held_balance };
}

function ledgerDto(e) {
  return {
    id: e.id,
    type: e.entry_type,
    amount: e.entry_type === 'PAYOUT' ? `-${e.amount}` : e.amount,
    balanceAfter: e.balance_after,
    heldAfter: e.held_after,
    refType: e.ref_type,
    refId: e.ref_id,
    createdAt: e.created_at,
  };
}

function withdrawalDto(w) {
  return {
    id: w.id,
    amount: w.amount,
    fee: w.fee,
    totalAmount: w.total_amount,
    bankCode: w.bank_code,
    accountNumber: w.account_number,
    accountName: w.account_name,
    status: w.status,
    createdAt: w.created_at,
    processedAt: w.processed_at,
  };
}

export async function get(req, res) {
  res.json(walletDto(await service.getWallet(req.user.id)));
}

export async function topup(req, res) {
  const { amount } = topupSchema.parse(req.body);
  const key = req.get('Idempotency-Key');
  if (!idempotencyKeySchema.safeParse(key).success) {
    throw new AppError(422, 'VALIDATION_ERROR', 'Header Idempotency-Key wajib (8-100 karakter).');
  }
  const { entry, created } = await service.topup(req.user.id, amount, key);
  res.status(created ? 201 : 200).json(ledgerDto(entry));
}

export async function ledger(req, res) {
  const { page } = pageSchema.parse(req.query);
  res.json({ items: (await service.listLedger(req.user.id, page)).map(ledgerDto), page });
}

export async function withdraw(req, res) {
  const request = withdrawalSchema.parse(req.body);
  const key = req.get('Idempotency-Key');
  if (!idempotencyKeySchema.safeParse(key).success) {
    throw new AppError(422, 'VALIDATION_ERROR', 'Header Idempotency-Key wajib (8-100 karakter).');
  }
  const result = await service.withdraw(req.user.id, request, key);
  res.status(result.created ? 201 : 200).json(withdrawalDto(result.withdrawal));
}

export async function withdrawals(req, res) {
  const { page } = pageSchema.parse(req.query);
  res.json({
    items: (await service.listWithdrawals(req.user.id, page)).map(withdrawalDto),
    page,
  });
}
