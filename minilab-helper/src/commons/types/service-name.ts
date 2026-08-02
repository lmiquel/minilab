// `ServiceName` est dérivé de `SERVICES` (sa source de vérité reste le
// dictionnaire docker-services-dictionary), mais comme la plupart des
// modules le consomment aux côtés des types communs, on le ré-exporte ici
// pour que tout le monde puisse importer ses types depuis un seul endroit.
export type { ServiceName } from "../../dictionaries/docker-services-dictionary/types/service-name";
