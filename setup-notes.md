# Openshift Post Install Notes

## Setup htpasswd identity provider

Details are at: <https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/authentication_and_authorization/configuring-identity-providers>

### Create an htpasswd file

```bash
htpasswd -c -B -b </path/to/htpasswd> <username> <password>
```

- at least one user should be "troy".
- add additional users with the same command sans the `-c`.

### Create the htpasswd secret

This will create a secret in the openshift-config namespace based upon the htpasswd file created in the step above.

```bash
oc create secret generic htpasswd-secret \
  --from-file=htpasswd=htpasswd \
  -n openshift-config
```

### Create OAuth htpasswd provider

This will create the htpasswd identity provider.  It will use the htpasswd-secret secret created in the step above

```bash
oc apply -f htpasswd-provider-oauth.yaml
```

### Give user "troy" admin priviledges

```bash
oc adm policy add-cluster-role-to-user cluster-admin troy
```

### Delete the kubeadmin user

```bash
oc delete secret kubeadmin -n kube-system
```

## Set up csi-nfs storage via helm chart

## Install the LVM Storage Operator

## Set up image registry storage

### If cluster is SNO, create the PVC in advance for LVM Storage

```bash
oc apply -f sno-image-registry-storage-pvc.yaml
```

### Modify the image registry configuration

```bash
oc edit configs.imageregistry.operator.openshift.io
```

For HA cluster:

```bash
oc patch configs.imageregistry.operator.openshift.io/cluster \
  --type=merge \
  --patch-file=image-registry-storage-patch.json
```

For SNO cluster:

```bash
oc patch configs.imageregistry.operator.openshift.io/cluster \
  --type=merge \
  --patch-file=sno-image-registry-storage-patch.json
```

## Replace tls certificates with LetsEncrypt certificates

Details are at: <https://stephennimmo.com/2024/05/15/generating-lets-encrypt-certificates-with-red-hat-openshift-cert-manager-operator-using-the-cloudflare-dns-solver/>

### Install the cert-manager operator

### Get an api token from CloudFlare dns

### Create a secret for Cloudflare dns api token

```bash
oc create secret generic cloudflare-api-token-secret \
  -n cert-manager \
  --from-literal=api-token=<token>
  ```

### Create a LetsEncrypt ClusterIssuer and ankersen.dev certificates

```bash
oc apply -f ankersen-dev-certificates.yaml
```

### Download the LetsEncrypt CA certificate

<https://letsencrypt.org/certs/isrgrootx1.pem>

```bash
curl https://letsencrypt.org/certs/isrgrootx1.pem > ./letsencrypt.pem
```

### Create a ConfigMap for LetsEncrypt ca certificate

```bash
oc create configmap letsencrypt-ca \
  --from-file=ca-bundle.crt=./letsencrypt.pem \
  -n openshift-config
```

### Add LetsEncrypt ca to cluster

```bash
oc patch proxy cluster \
  --type=merge \
  --patch='{"spec": {"trustedCA": {"name": "letsencrypt-ca"}}}'
```

### Update the default IngressController to use the LetsEncrypt wildcard tls

```bash
oc patch ingresscontroller.operator default \
  --type=merge \
  --patch '{"spec": {"defaultCertificate": {"name": "apps-ocp-ankersen-dev-tls"}}}' \
  -n openshift-ingress-operator
```

### Update the api server to use the LetsEncrypt wildcard tls

```bash
oc patch apiserver cluster \
  --type=merge \
  --patch '{"spec": {"servingCerts": {"namedCertificates": [{"names": ["api.ocp.ankersen.dev"], "servingCertificate": {"name": "api-ocp-ankersen-dev-tls"}}]}}}' 
```

## Alerting Setup

### AlertManager Default Receiver

SMTP smarthost: smtp.gmail.com:587  
Auth username: CaskAle13c  
Auth password (using LOGIN and PLAIN): use app password

### Set up persistent storage for cluster monitoring

- Assumes that the LVM Storage Operator is installed.
- StorageClass `odf-lvm-vg1`

```bash
oc apply -f cluster-monitoring-config.yaml
```

## Virtualization Networking

### Node Network Configuration Policy to create br-ex network

```yaml
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: br-ex-vlan20
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: '' 
  desiredState:
    ovn:
      bridge-mappings:
      - localnet: br-ex-vlan20
        bridge: br-ex 
        state: present
```

## Network Attachment Definition

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  annotations: {}
  name: br-ex-vlan20
  namespace: virtual-machines
spec:
  config: |-
    {
        "cniVersion": "0.4.0",
        "name": "br-ex-vlan20",
        "type": "ovn-k8s-cni-overlay",
        "netAttachDefName": "virtual-machines/br-ex-vlan20",
        "topology": "localnet"
    }
```

## Grow the root filesystem in CoreOS

```bash
sudo su
growpart /dev/sda 4
sudo su -
unshare --mount
mount -o remount,rw /sysroot
xfs_growfs /sysroot
```

## Set up etcd defragmentation cron job

```bash
 oc create -k kustomization.yaml
 ```

## Set cpu governor on nodes
