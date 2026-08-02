import type { HostStorageInfo } from "../../../commons/types/host-storage-info";

export interface HostStorageUsage {
  sd: HostStorageInfo;
  ssd: HostStorageInfo;
}
