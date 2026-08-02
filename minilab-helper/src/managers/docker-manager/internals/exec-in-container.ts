import type Dockerode from "dockerode";
import type { ServiceName } from "../../../commons/types/service-name";
import { SERVICES } from "../../../dictionaries/docker-services-dictionary/docker-services-dictionary";

/**
 * Exécute une commande dans un conteneur et retourne le stdout.
 *
 * Le stream Docker exec est multiplexé (format 8-byte header par frame).
 * On utilise demuxStream pour séparer stdout/stderr correctement,
 * en accumulant les chunks dans des PassThrough streams — ce qui évite toute
 * corruption binaire liée à chunk.toString() sur des données non-UTF8.
 */
export async function execInContainer(docker: Dockerode, service: ServiceName, cmd: string): Promise<string> {
  const { PassThrough } = await import("stream");

  const container = docker.getContainer(SERVICES[service].containerName);
  const exec = await container.exec({
    Cmd: cmd.split(" "),
    AttachStdout: true,
    AttachStderr: true,
  });

  const stream = await exec.start({ hijack: true, stdin: false });

  return new Promise<string>((resolve, reject) => {
    const stdout = new PassThrough();
    const stderr = new PassThrough();

    const chunks: Buffer[] = [];
    stdout.on("data", (chunk: Buffer) => chunks.push(chunk));

    stream.on("error", reject);
    stdout.on("error", reject);

    stream.on("end", () => {
      resolve(Buffer.concat(chunks).toString("utf8"));
    });

    (container as any).modem.demuxStream(stream, stdout, stderr);
  });
}
