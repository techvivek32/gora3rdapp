export interface PaginationQuery {
  page?: number;
  limit?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

export interface PaginatedResult<T> {
  data: T[];
  meta: {
    total: number;
    page: number;
    limit: number;
    totalPages: number;
    hasNextPage: boolean;
    hasPrevPage: boolean;
  };
}

export function getPaginationParams(query: PaginationQuery) {
  const page = Math.max(1, Number(query.page) || 1);
  const limit = Math.min(100, Math.max(1, Number(query.limit) || 20));
  const skip = (page - 1) * limit;
  const sort: Record<string, 1 | -1> = {
    [query.sortBy || 'createdAt']: query.sortOrder === 'asc' ? 1 : -1,
  };

  return { page, limit, skip, sort };
}

/**
 * Builds a Mongo date-range filter fragment from `dateFrom` / `dateTo` query params
 * (inclusive of the whole "to" day). Returns `{}` when neither is provided, so it can
 * be spread straight into a filter object.
 */
export function dateRangeFilter(query: any, field = 'createdAt'): Record<string, any> {
  const from = query?.dateFrom || query?.from;
  const to = query?.dateTo || query?.to;
  if (!from && !to) return {};
  const range: Record<string, Date> = {};
  if (from) {
    const d = new Date(from);
    if (!isNaN(d.getTime())) range.$gte = d;
  }
  if (to) {
    const d = new Date(to);
    if (!isNaN(d.getTime())) {
      d.setHours(23, 59, 59, 999); // include the entire end day
      range.$lte = d;
    }
  }
  return Object.keys(range).length ? { [field]: range } : {};
}

export function buildPaginatedResult<T>(
  data: T[],
  total: number,
  page: number,
  limit: number,
): PaginatedResult<T> {
  const totalPages = Math.ceil(total / limit);
  return {
    data,
    meta: {
      total,
      page,
      limit,
      totalPages,
      hasNextPage: page < totalPages,
      hasPrevPage: page > 1,
    },
  };
}
