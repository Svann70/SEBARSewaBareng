// Enum types and custom column types shared by the schema files.
import { customType, pgEnum } from "drizzle-orm/pg-core";

// Case-insensitive text (users.email).
export const citext = customType({ dataType: () => "citext" });

export const bookingStatus = pgEnum("booking_status", ['CONFIRMED', 'COMPLETED', 'CANCELLED'])
export const checkinStatus = pgEnum("checkin_status", ['PENDING', 'SCANNED', 'EXPIRED', 'NO_SHOW'])
export const courtStatus = pgEnum("court_status", ['ACTIVE', 'MAINTENANCE'])
export const ledgerType = pgEnum("ledger_type", ['TOPUP', 'HOLD', 'RELEASE', 'CAPTURE', 'REFUND', 'PAYOUT', 'PENALTY'])
export const lobbyStatus = pgEnum("lobby_status", ['OPEN', 'FILLED', 'CONFIRMED', 'CANCELLED', 'EXPIRED', 'FAILED'])
export const memberRole = pgEnum("member_role", ['HOST', 'PLAYER'])
export const memberStatus = pgEnum("member_status", ['HOLDING', 'CONFIRMED', 'CANCELLED', 'REFUNDED', 'PENALIZED', 'NO_SHOW'])
export const payoutStatus = pgEnum("payout_status", ['PENDING', 'PAID'])
export const reliabilityReason = pgEnum("reliability_reason", ['CHECKIN', 'LATE_CANCEL', 'NO_SHOW', 'HOST_CANCEL', 'MANUAL_ADJUST'])
export const slotStatus = pgEnum("slot_status", ['OPEN', 'LOBBY_FULL', 'BOOKED', 'BLOCKED', 'PAST'])
export const sportType = pgEnum("sport_type", ['BADMINTON', 'FUTSAL', 'VOLLEY', 'MINISOCCER', 'BASKETBALL', 'TENNIS', 'PADEL'])
export const userRole = pgEnum("user_role", ['PLAYER', 'VENUE_ADMIN', 'SUPER_ADMIN'])
export const venueStatus = pgEnum("venue_status", ['ACTIVE', 'INACTIVE'])
