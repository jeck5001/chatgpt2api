export const DEFAULT_AUTO_RETRY_LIMIT = 3;
export const MAX_AUTO_RETRY_LIMIT = 10;

export type AutoRetryImage = {
  id: string;
  taskId?: string;
  status?: "loading" | "success" | "error";
  retryAttempt?: number;
  error?: string;
};

export type AutoRetryResult<T extends AutoRetryImage> = {
  images: T[];
  changed: boolean;
  retriedCount: number;
};

function isAutoRetryableError(error: string | undefined): boolean {
  return !error?.includes("超时");
}

export function normalizeAutoRetryLimit(value: unknown): number {
  if (value === undefined || value === null || value === "") {
    return DEFAULT_AUTO_RETRY_LIMIT;
  }
  const parsed = Math.floor(Number(value));
  if (!Number.isFinite(parsed)) {
    return DEFAULT_AUTO_RETRY_LIMIT;
  }
  return Math.min(MAX_AUTO_RETRY_LIMIT, Math.max(0, parsed));
}

export function retryFailedImagesWithinLimit<T extends AutoRetryImage>(
  images: T[],
  {
    turnId,
    autoRetryLimit,
    createId,
  }: {
    turnId: string;
    autoRetryLimit: number;
    createId: () => string;
  }
): AutoRetryResult<T> {
  const limit = normalizeAutoRetryLimit(autoRetryLimit);
  if (limit <= 0) {
    return { images, changed: false, retriedCount: 0 };
  }

  let changed = false;
  let retriedCount = 0;
  const nextImages = images.map((image) => {
    if (image.status !== "error") {
      return image;
    }
    if (!isAutoRetryableError(image.error)) {
      return image;
    }
    const retryAttempt = Math.max(
      0,
      Math.floor(Number(image.retryAttempt) || 0)
    );
    if (retryAttempt >= limit) {
      return image;
    }

    const id = `${turnId}-${createId()}`;
    changed = true;
    retriedCount += 1;
    return {
      id,
      taskId: id,
      status: "loading" as const,
      retryAttempt: retryAttempt + 1,
    } as T;
  });

  return {
    images: nextImages,
    changed,
    retriedCount,
  };
}
