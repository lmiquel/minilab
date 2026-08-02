import Dockerode from "dockerode";

export function createDockerClient(): Dockerode {
  const dockerHost = process.env.DOCKER_HOST as string;
  const url = new URL(dockerHost);
  return new Dockerode({ host: url.hostname, port: Number(url.port) || 2375 });
}
