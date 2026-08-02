import { describe, it } from "node:test";
import assert from "node:assert/strict";
import type { ContainerStatus } from "../commons/types/container-status";
import { HealthStatus } from "../commons/types/health-status";
import { renderContainerStateLine } from "../managers/commands-manager/internals/helpers/render-container-state-line";

function status(overrides: Partial<ContainerStatus>): ContainerStatus {
  return {
    name: "valheim",
    containerId: "abc123",
    state: "running",
    status: "running",
    restartCount: 0,
    health: HealthStatus.None,
    ...overrides,
  };
}

describe("renderContainerStateLine", () => {
  it("shows the health status when running with a healthcheck", () => {
    assert.equal(
      renderContainerStateLine(status({ state: "running", health: HealthStatus.Healthy })),
      "💚 `healthy`"
    );
    assert.equal(
      renderContainerStateLine(status({ state: "running", health: HealthStatus.Unhealthy })),
      "❤️‍🩹 `unhealthy`"
    );
  });

  it("falls back to the Docker state when there's no healthcheck", () => {
    assert.equal(renderContainerStateLine(status({ state: "running", health: HealthStatus.None })), "🟢 `running`");
    assert.equal(renderContainerStateLine(status({ state: "exited", health: HealthStatus.None })), "🔴 `exited`");
  });

  it("shows the Docker state (not the stale health) when not running", () => {
    assert.equal(
      renderContainerStateLine(status({ state: "exited", health: HealthStatus.Unhealthy })),
      "🔴 `exited`"
    );
  });
});
