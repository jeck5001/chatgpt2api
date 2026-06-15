import { describe, expect, test } from "bun:test";

import {
  DEFAULT_AUTO_RETRY_LIMIT,
  normalizeAutoRetryLimit,
  retryFailedImagesWithinLimit,
} from "../src/lib/image-auto-retry";

describe("image auto retry policy", () => {
  test("defaults each conversation to three automatic retries", () => {
    expect(DEFAULT_AUTO_RETRY_LIMIT).toBe(3);
    expect(normalizeAutoRetryLimit(undefined)).toBe(3);
  });

  test("treats zero as disabled", () => {
    const result = retryFailedImagesWithinLimit(
      [
        {
          id: "image-1",
          taskId: "task-1",
          status: "error" as const,
          error: "failed",
        },
      ],
      {
        turnId: "turn-1",
        autoRetryLimit: 0,
        createId: () => "retry-1",
      }
    );

    expect(result.changed).toBe(false);
    expect(result.retriedCount).toBe(0);
    expect(result.images[0]).toMatchObject({
      id: "image-1",
      taskId: "task-1",
      status: "error",
      error: "failed",
    });
  });

  test("requeues failed images until the per-conversation threshold is reached", () => {
    const result = retryFailedImagesWithinLimit(
      [
        {
          id: "image-1",
          taskId: "task-1",
          status: "error" as const,
          error: "failed",
          retryAttempt: 2,
        },
      ],
      {
        turnId: "turn-1",
        autoRetryLimit: 3,
        createId: () => "retry-3",
      }
    );

    expect(result.changed).toBe(true);
    expect(result.retriedCount).toBe(1);
    expect(result.images[0]).toEqual({
      id: "turn-1-retry-3",
      taskId: "turn-1-retry-3",
      status: "loading",
      retryAttempt: 3,
    });
  });

  test("leaves failed images untouched after the retry threshold is reached", () => {
    const result = retryFailedImagesWithinLimit(
      [
        {
          id: "image-1",
          taskId: "task-1",
          status: "error" as const,
          error: "failed",
          retryAttempt: 3,
        },
      ],
      {
        turnId: "turn-1",
        autoRetryLimit: 3,
        createId: () => "retry-4",
      }
    );

    expect(result.changed).toBe(false);
    expect(result.retriedCount).toBe(0);
    expect(result.images[0]).toMatchObject({
      id: "image-1",
      taskId: "task-1",
      status: "error",
      error: "failed",
      retryAttempt: 3,
    });
  });

  test("does not auto retry timeout errors so manual continue can resume polling", () => {
    const result = retryFailedImagesWithinLimit(
      [
        {
          id: "image-1",
          taskId: "task-1",
          status: "error" as const,
          error: "生图超时",
          retryAttempt: 0,
        },
      ],
      {
        turnId: "turn-1",
        autoRetryLimit: 3,
        createId: () => "retry-1",
      }
    );

    expect(result.changed).toBe(false);
    expect(result.retriedCount).toBe(0);
    expect(result.images[0]).toMatchObject({
      id: "image-1",
      taskId: "task-1",
      status: "error",
      error: "生图超时",
      retryAttempt: 0,
    });
  });
});
