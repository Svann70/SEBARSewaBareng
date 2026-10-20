import { AppError } from '../../lib/errors.js';
import { idempotencyKeySchema, pageSchema, topupSchema } from './wallet.schema.js';
import * as service from './wallet.service.js';

function walletDto(w) {
  return { balance: w.balance, held: w.held_balance, available: w.balance - w.held_balance };
}

function ledgerDto(e) {
  return {
    id: e.id,
    type: e.entry_type,
    amount: e.amount,
    balanceAfter: e.balance_after,
    heldAfter: e.held_after,
    refType: e.ref_type,
    refId: e.ref_id,
    createdAt: e.created_at,
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
