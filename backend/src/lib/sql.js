// Calendar dates are Indonesia Western Time (SDD §17.2). `param` is a placeholder like '$2'.
export const onDateWib = (column, param) => `(${column} AT TIME ZONE 'Asia/Jakarta')::date = ${param}::date`;

export const SPORTS = ['BADMINTON', 'FUTSAL', 'VOLLEY', 'MINISOCCER', 'BASKETBALL', 'TENNIS', 'PADEL'];

// Start of a WIB calendar date as timestamptz. `param` is a placeholder like '$2'.
export const wibDayStart = (param) => `(${param}::date::timestamp AT TIME ZONE 'Asia/Jakarta')`;
