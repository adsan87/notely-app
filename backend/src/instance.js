import os from 'node:os';

// Identifies WHICH instance serves each request. Covers all four deployment
// stages: single VM -> MIG -> MIG behind a Load Balancer -> Cloud Run.
//
// Resolved once at startup (the metadata server does not change during an
// instance's lifetime), so /health never pays for a network round trip.

const METADATA_HOST = 'http://metadata.google.internal/computeMetadata/v1';
const METADATA_TIMEOUT_MS = Number(process.env.METADATA_TIMEOUT_MS || 1000);

// The metadata server only exists inside GCP. Outside it fails fast on DNS, but
// the timeout keeps a local startup from hanging if something does resolve.
async function metadata(path) {
  try {
    const res = await fetch(`${METADATA_HOST}/${path}`, {
      headers: { 'Metadata-Flavor': 'Google' },
      signal: AbortSignal.timeout(METADATA_TIMEOUT_MS),
    });
    if (!res.ok) return null;
    const text = (await res.text()).trim();
    return text === '' ? null : text;
  } catch {
    return null;
  }
}

// zone -> "projects/123/zones/us-central1-b" -> "us-central1-b"
const lastSegment = (v) => (v ? v.split('/').pop() : null);

function primaryIpv4() {
  return Object.values(os.networkInterfaces())
    .flat()
    .find((i) => i && i.family === 'IPv4' && !i.internal)?.address ?? null;
}

export async function resolveInstance() {
  const hostname = os.hostname();
  const onCloudRun = Boolean(process.env.K_SERVICE);

  // Cheap probe: if the metadata server does not answer, we are running locally.
  const projectId = await metadata('project/project-id');
  const onGcp = projectId !== null;

  const base = {
    platform: onCloudRun ? 'cloud-run' : onGcp ? 'gce' : 'local',
    name: hostname,
    hostname,
    ip: primaryIpv4() ?? 'unknown',
    pid: process.pid,
    node: process.version,
    startedAt: new Date().toISOString(),
  };

  if (!onGcp) return Object.freeze(base);

  const [id, gceName, zone, region, machineType, internalIp, externalIp, createdBy] =
    await Promise.all([
      metadata('instance/id'),
      metadata('instance/name'),
      metadata('instance/zone'),
      metadata('instance/region'),
      metadata('instance/machine-type'),
      metadata('instance/network-interfaces/0/ip'),
      metadata('instance/network-interfaces/0/access-configs/0/external-ip'),
      // Only set on instances created by a MIG:
      // "projects/123/zones/Z/instanceGroupManagers/notely-mig"
      metadata('instance/attributes/created-by'),
    ]);

  const zoneName = lastSegment(zone);

  const gcp = {
    ...base,
    // On a VM the instance name is the identifying bit; Cloud Run has no
    // instance name, so the revision plus the container id play that role.
    name: onCloudRun
      ? `${process.env.K_REVISION ?? 'unknown-revision'}/${hostname.slice(0, 12)}`
      : gceName ?? hostname,
    projectId,
    instanceId: id,
    zone: zoneName,
    region: lastSegment(region) ?? zoneName?.replace(/-[a-z]$/, '') ?? null,
    internalIp: internalIp ?? base.ip,
    externalIp,                                  // null behind a load balancer or NAT
    machineType: lastSegment(machineType),
    mig: createdBy?.includes('/instanceGroupManagers/')
      ? lastSegment(createdBy)
      : null,
  };

  if (onCloudRun) {
    gcp.service = process.env.K_SERVICE ?? null;
    gcp.revision = process.env.K_REVISION ?? null;
    gcp.configuration = process.env.K_CONFIGURATION ?? null;
  }

  // Empty fields would only clutter the /health response.
  return Object.freeze(
    Object.fromEntries(Object.entries(gcp).filter(([, v]) => v !== null)),
  );
}
