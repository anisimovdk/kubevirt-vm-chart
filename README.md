# kubevirt-vm-chart

A single-chart Helm repository for deploying KubeVirt VirtualMachines with a CDI-managed root volume.

The chart reuses the repository conventions from `argo-ci-charts` and the KubeVirt domain model from the existing `home-k8s` `kubevirt-vm` chart, but updates the implementation to current stable APIs:

- KubeVirt `v1.8.1`
- CDI `v1.65.0`

## Table of Contents

- [Description](#description)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Root Volume Sources](#root-volume-sources)
- [Usage Examples](#usage-examples)
- [Development](#development)
- [License](#license)

## Description

This chart renders:

- One `VirtualMachine`
- One chart-managed CDI `DataVolumeTemplate` for the root disk
- One optional cloud-init volume using NoCloud or ConfigDrive
- One optional chart-managed `NetworkAttachmentDefinition` for Multus bridge networking
- Optional SSH key `Secret` resources for `accessCredentials`
- Optional `NetworkPolicy` resources for the VM pod and CDI importer pods

The root disk stays intentionally simple in v1: the chart supports one boot or root volume, but that volume can be populated from multiple CDI source kinds or from `sourceRef`.

## Prerequisites

- Kubernetes 1.30+
- Helm 3.0+
- KubeVirt installed and working
- CDI installed and working
- Multus installed when `interfaces.bridge.enabled=true`

## Installation

### From Local Source

```bash
helm install my-vm .
```

### From OCI Registry

```bash
helm install my-vm oci://docker.io/anisimovdk/kubevirt-vm --version 0.1.0
```

## Configuration

### General

| Parameter | Description | Default |
| --- | --- | --- |
| `nameOverride` | Override the chart name used in resource names | `""` |
| `fullnameOverride` | Override the full resource name prefix (`<release>-<chart>`) | `""` |

### VirtualMachine

| Parameter | Description | Default |
| --- | --- | --- |
| `virtualMachine.annotations` | Extra annotations added to the `VirtualMachine` resource | `{}` |
| `virtualMachine.labels` | Extra labels added to the `VirtualMachine` resource | `{}` |
| `virtualMachine.hostname` | Hostname assigned to the guest OS. Defaults to release name if empty | `""` |
| `virtualMachine.runStrategy` | VM power state lifecycle: `Always`, `Halted`, `Manual`, `RerunOnFailure`, `Once`. `Always` keeps the VM running and restarts it on failure (replaces deprecated `spec.running: true`) | `Always` |
| `virtualMachine.terminationGracePeriodSeconds` | Seconds virt-controller waits for the guest to shut down gracefully before forcing off | `180` |

### OS / Instance Type Labels

These values are applied as scheduling and informational labels on the `VirtualMachine`, mapping to `kubevirt.io/os`, `flavor.template.kubevirt.io/<flavor>`, and `workload.template.kubevirt.io/<workload>`.

| Parameter | Description | Default |
| --- | --- | --- |
| `os.name` | Guest OS identifier, e.g. `ubuntu`, `fedora`, `windows` | `ubuntu` |
| `os.flavor` | T-shirt size hint: `tiny`, `small`, `medium`, `large`, `xlarge` | `small` |
| `os.workload` | Workload type hint: `server`, `desktop`, `highperformance` | `server` |

### CPU and Memory

| Parameter | Description | Default |
| --- | --- | --- |
| `cpu.cores` | Number of cores per socket | `1` |
| `cpu.sockets` | Number of CPU sockets | `1` |
| `cpu.threads` | Number of threads per core (total vCPUs = cores × sockets × threads) | `1` |
| `memory` | Guest RAM, e.g. `2Gi`, `512Mi` | `2Gi` |

### Root Volume

| Parameter | Description | Default |
| --- | --- | --- |
| `rootVolume.annotations` | Extra annotations added to the `DataVolume` resource | `{}` |
| `rootVolume.labels` | Extra labels added to the `DataVolume` resource | `{}` |
| `rootVolume.bootOrder` | Boot order index for this disk (`1` = first) | `1` |
| `rootVolume.contentType` | CDI content type: `kubevirt` for VM images, `archive` for tar archives | `kubevirt` |
| `rootVolume.preallocation` | Pre-allocate storage on the target PV for better I/O (increases provisioning time) | `false` |
| `rootVolume.priorityClassName` | PriorityClass for the CDI importer pod. Leave empty for the cluster default | `""` |
| `rootVolume.disk.bus` | Disk bus type: `virtio` (fastest), `sata`, `scsi` | `virtio` |
| `rootVolume.disk.cache` | Disk cache mode: `""`, `none`, `writethrough`, `writeback` | `""` |
| `rootVolume.disk.io` | I/O mode: `""`, `native`, `threads` | `""` |
| `rootVolume.disk.dedicatedIOThread` | Pin a dedicated I/O thread to this disk for lower latency | `false` |
| `rootVolume.disk.shareable` | Allow multiple VMs to share this disk (requires `ReadWriteMany` PV) | `false` |
| `rootVolume.disk.errorPolicy` | I/O error policy: `""`, `stop`, `report`, `ignore`, `enospace` | `""` |
| `rootVolume.storage.accessModes` | PV access modes. `ReadWriteOnce` is sufficient for single-node VMs | `[ReadWriteOnce]` |
| `rootVolume.storage.storageClassName` | StorageClass name. Leave empty to use the cluster default | `""` |
| `rootVolume.storage.volumeMode` | Volume mode: `Filesystem` or `Block` | `Filesystem` |
| `rootVolume.storage.resources.requests.storage` | Disk size. Must be ≥ the uncompressed image size | `10Gi` |

#### Root Volume Source

Set `rootVolume.source.type` to select the CDI import method. Only the matching sub-key is used; all others are ignored. Mutually exclusive with `rootVolume.sourceRef`.

| Parameter | Description | Default |
| --- | --- | --- |
| `rootVolume.source.type` | Active source type. One of: `blank`, `http`, `registry`, `s3`, `gcs`, `pvc`, `snapshot`, `upload`, `imageio`, `vddk` | `http` |
| `rootVolume.source.blank` | Create an empty disk — no import | `{}` |
| `rootVolume.source.http.url` | URL to the disk image | Ubuntu Noble cloud image |
| `rootVolume.source.http.secretRef` | Secret with HTTP basic-auth credentials (`accessKeyId` / `secretKey`) | `""` |
| `rootVolume.source.http.certConfigMap` | ConfigMap with additional CA certificates for TLS | `""` |
| `rootVolume.source.http.extraHeaders` | Static extra HTTP request headers | `[]` |
| `rootVolume.source.http.secretExtraHeaders` | Secret whose values are added as HTTP headers (sensitive) | `[]` |
| `rootVolume.source.registry.url` | Registry URL including image and tag, e.g. `docker://quay.io/containerdisks/fedora:latest` | `""` |
| `rootVolume.source.registry.imageStream` | OpenShift ImageStream name (OpenShift only) | `""` |
| `rootVolume.source.registry.pullMethod` | Image pull method: `""` or `pod` | `""` |
| `rootVolume.source.registry.secretRef` | Secret with registry credentials (docker config JSON) | `""` |
| `rootVolume.source.registry.certConfigMap` | ConfigMap with CA certificates for registry TLS | `""` |
| `rootVolume.source.registry.platform.architecture` | Target CPU architecture, e.g. `amd64`, `arm64` | `""` |
| `rootVolume.source.s3.url` | S3 endpoint URL including bucket and object key | `""` |
| `rootVolume.source.s3.secretRef` | Secret with S3 credentials (`accessKeyId` / `secretKey`) | `""` |
| `rootVolume.source.s3.certConfigMap` | ConfigMap with CA certificates for S3 TLS | `""` |
| `rootVolume.source.gcs.url` | GCS object URL (`gs://bucket/object`) | `""` |
| `rootVolume.source.gcs.secretRef` | Secret with GCS service account key JSON | `""` |
| `rootVolume.source.pvc.name` | Name of the source PVC to clone | `""` |
| `rootVolume.source.pvc.namespace` | Namespace of the source PVC. Defaults to release namespace | `""` |
| `rootVolume.source.snapshot.name` | Name of the VolumeSnapshot to restore | `""` |
| `rootVolume.source.snapshot.namespace` | Namespace of the VolumeSnapshot. Defaults to release namespace | `""` |
| `rootVolume.source.upload` | Provision via CDI upload proxy (`virtctl image-upload`) — no additional fields | `{}` |
| `rootVolume.source.imageio.url` | imageio endpoint URL | `""` |
| `rootVolume.source.imageio.diskId` | Disk ID on the imageio server | `""` |
| `rootVolume.source.imageio.secretRef` | Secret with imageio credentials | `""` |
| `rootVolume.source.imageio.certConfigMap` | ConfigMap with CA certificates for imageio TLS | `""` |
| `rootVolume.source.imageio.insecureSkipVerify` | Skip TLS certificate verification (not recommended for production) | `false` |
| `rootVolume.source.vddk.url` | vCenter/ESXi URL, e.g. `https://vcenter.example.com/sdk` | `""` |
| `rootVolume.source.vddk.uuid` | VM UUID on vSphere | `""` |
| `rootVolume.source.vddk.backingFile` | VMDK backing file path on the datastore | `""` |
| `rootVolume.source.vddk.secretRef` | Secret with vSphere credentials (`user` / `password`) | `""` |
| `rootVolume.source.vddk.thumbprint` | SSL thumbprint of the vSphere host certificate | `""` |
| `rootVolume.source.vddk.initImageURL` | VDDK init container image, e.g. `registry.example.com/vddk:8.0` | `""` |
| `rootVolume.source.vddk.extraArgs` | Extra arguments passed to the VDDK importer | `""` |

#### Root Volume SourceRef

Use `sourceRef` to provision from a pre-existing CDI `DataSource` (e.g. maintained by an admin). Mutually exclusive with `rootVolume.source`.

| Parameter | Description | Default |
| --- | --- | --- |
| `rootVolume.sourceRef.enabled` | Use a `DataSource` reference instead of a direct source | `false` |
| `rootVolume.sourceRef.kind` | DataSource kind (currently only `DataSource` is supported) | `DataSource` |
| `rootVolume.sourceRef.name` | Name of the `DataSource` resource | `""` |
| `rootVolume.sourceRef.namespace` | Namespace of the `DataSource`. Defaults to release namespace | `""` |

### Cloud-Init

| Parameter | Description | Default |
| --- | --- | --- |
| `cloudInit.enabled` | Enable cloud-init disk injection | `true` |
| `cloudInit.type` | Datasource type presented to the guest: `noCloud` or `configDrive` | `noCloud` |
| `cloudInit.disk.bus` | Disk bus for the cloud-init ISO: `virtio` or `sata` | `virtio` |
| `cloudInit.config.username` | Default OS user created by cloud-init | `ubuntu` |
| `cloudInit.config.password` | Password for the default user. Leave empty to disable password login | `""` |
| `cloudInit.config.passwordExpire` | Force password change on first login | `false` |
| `cloudInit.config.sshPasswordAuth` | Allow SSH password authentication (prefer key-based auth) | `false` |
| `cloudInit.firstBoot.commands` | List of shell commands rendered into cloud-init `runcmd`. Mutually exclusive with raw userData overrides | `[]` |
| `cloudInit.userData` | Plain-text cloud-config or script. Bypasses `config` + `firstBoot`. Ignored when `userDataBase64` or `userDataSecretRef` is set | `""` |
| `cloudInit.userDataBase64` | Base64-encoded user-data. Takes precedence over `userData` | `""` |
| `cloudInit.userDataSecretRef` | Name of a Secret whose `userdata` key contains the user-data. Highest precedence | `""` |
| `cloudInit.networkData` | Plain-text network-config (cloud-init network v1/v2 YAML) | `""` |
| `cloudInit.networkDataBase64` | Base64-encoded network-config | `""` |
| `cloudInit.networkDataSecretRef` | Name of a Secret whose `networkdata` key contains the network-config | `""` |

**User-data precedence (highest → lowest):** `userDataSecretRef` → `userDataBase64` → `userData` → generated from `config` + `firstBoot.commands`.

### Interfaces

| Parameter | Description | Default |
| --- | --- | --- |
| `interfaces.masquerade.enabled` | Enable pod-network masquerade (NAT) interface. Required for outbound internet access | `true` |
| `interfaces.masquerade.name` | Interface name inside the VM | `default` |
| `interfaces.masquerade.model` | NIC model: `virtio` (recommended), `e1000`, `rtl8139` | `virtio` |
| `interfaces.masquerade.ports` | Ports to expose through the masquerade NAT. KubeVirt creates iptables DNAT rules only for listed ports — required for `virtctl ssh` / `virtctl vnc` to reach the VM. Set to `[]` for permissive (all-ports) mode | `[{port: 22, protocol: TCP}]` |
| `interfaces.bridge.enabled` | Enable bridge interface. Requires Multus CNI | `false` |
| `interfaces.bridge.name` | Interface name inside the VM | `bridge` |
| `interfaces.bridge.model` | NIC model: `virtio` (recommended), `e1000`, `rtl8139` | `virtio` |
| `interfaces.bridge.config.name` | Name of the `NetworkAttachmentDefinition` created by the chart | `kubevirt-bridge` |
| `interfaces.bridge.config.cniVersion` | CNI spec version | `0.3.1` |
| `interfaces.bridge.config.type` | CNI plugin type | `bridge` |
| `interfaces.bridge.config.mtu` | Bridge MTU. Set to match your physical network MTU minus encapsulation overhead | `1300` |

### NetworkPolicy

| Parameter | Description | Default |
| --- | --- | --- |
| `networkPolicy.enabled` | Enable `NetworkPolicy` for the virt-launcher pod | `false` |
| `networkPolicy.annotations` | Extra annotations added to the `NetworkPolicy` | `{}` |
| `networkPolicy.additionalLabels` | Extra labels added to the `NetworkPolicy` | `{}` |
| `networkPolicy.podLabels` | Additional pod selector labels for the VM pod (merged with chart-managed labels) | `{}` |
| `networkPolicy.ingress` | Ingress rules. Empty list means no ingress allowed | `[]` |
| `networkPolicy.egress` | Egress rules. Empty list means no egress allowed | `[]` |
| `networkPolicy.cdi.enabled` | Enable `NetworkPolicy` for the CDI importer pod | `false` |
| `networkPolicy.cdi.ingress` | Ingress rules for the CDI importer pod | `[]` |
| `networkPolicy.cdi.egress` | Egress rules for the CDI importer pod. Default allows all outbound so the importer can reach image sources | `[{to: [{ipBlock: {cidr: 0.0.0.0/0}}]}]` |

### SSH

| Parameter | Description | Default |
| --- | --- | --- |
| `ssh.enabled` | Enable SSH key injection via KubeVirt `accessCredentials` | `false` |
| `ssh.pubkeys` | Map of named SSH public keys. Key = Secret name suffix, value = public key string | Example key included |

## Root Volume Sources

When `rootVolume.sourceRef.enabled=false`, the chart renders `dataVolumeTemplates[0].spec.source` using `rootVolume.source.type`.

Supported values:

- `blank`
- `http`
- `registry`
- `s3`
- `gcs`
- `pvc`
- `snapshot`
- `upload`
- `imageio`
- `vddk`

When `rootVolume.sourceRef.enabled=true`, the chart renders `dataVolumeTemplates[0].spec.sourceRef` instead.

## Usage Examples

### Default HTTP Import

```yaml
rootVolume:
  source:
    type: http
    http:
      url: https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

### Registry Import

```yaml
rootVolume:
  source:
    type: registry
    registry:
      url: docker://quay.io/containerdisks/fedora:latest
```

### DataSource via SourceRef

```yaml
rootVolume:
  sourceRef:
    enabled: true
    kind: DataSource
    name: fedora-datasource
```

### First-Boot Commands

```yaml
cloudInit:
  config:
    username: ubuntu
  firstBoot:
    commands:
      - systemctl enable --now ssh
      - [sh, -c, "echo hello from first boot >/etc/motd"]
```

### Bridge Networking with Multus

```yaml
interfaces:
  bridge:
    enabled: true
    config:
      name: lab-bridge
      cniVersion: "0.3.1"
      type: bridge
      mtu: 1300
```

### Upload Source

```yaml
virtualMachine:
  runStrategy: Halted

rootVolume:
  source:
    type: upload
```

Use `Halted` for upload workflows so the VM does not try to boot before the upload completes.

## Development

Lint the chart:

```bash
make lint
```

Package the chart:

```bash
make build
```

Push the packaged chart to an OCI registry:

```bash
export DOCKER_USERNAME=your-username
export DOCKER_PASSWORD=your-password
make login
make push
```

## License

This project is licensed under the Apache License 2.0. See `LICENSE` for details.
