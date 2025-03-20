## Artifact Attestations with GitHub Actions

A repo to test how attestations work in GitHub Actions. We created a very simple (Hello World) express-js server in NodeJS which we containerize and attest. 

We are mostly interested in attesting container images, not files.

Attestations of our interest are:
1. SLSA Provenance
2. SBOM

### 1. Attest with Docker
One option is to use [Docker](https://docs.docker.com/build/metadata/attestations/) to generate attestations. When building images with Docker, we can mark the `provenance` and `sbom` parameters like this:

```sh
docker buildx build -t image/name:tag --provenance=true --sbom=true .
```

By default, Docker generates a provenance attestations and attaches it to the image (if uploaded to a registry). Docker supports two modes of provenance, min and max. These modes define the amount of information stored in the provenance (default is max).

To inspect the provenance or SBOM:
```sh
docker buildx imagetools inspect image/name:tag --format "{{ json .Provenance.SLSA }}"

docker buildx imagetools inspect image/name:tag --format "{{ json .SBOM.SPDX }}"
```

In GitHub Actions this is done with the docker/build-push-action:
```yaml
- name: Build and push Docker image
  uses: docker/build-push-action@v6.15.0
  id: build-and-push
  with:
    tags: CONTAINER_IMAGE_TAGS
    push: true
    provenance: true
    sbom: true
```

### 2. GitHub Actions native action

We can leverage premade GitHub Actions from the Marketplace to generate our attestations. There are two **official** actions for this:
1. [actions/attest-build-provenance](https://github.com/marketplace/actions/attest-build-provenance)
2. [actions/attest-sbom](https://github.com/marketplace/actions/attest-sbom)

Assuming we have already built our container image (e.g., using the docker/build-push-action). With the following action, we can generate the build provenance and attest it. This action uses Sigstore as a signing system.

```yaml
- name: Attest Provenance
  uses: actions/attest-build-provenance@v2.2.3
  id: attest-provenance
  with:
    subject-name: CONTAINER_IMAGE_NAME
    subject-digest: CONTAINER_IMAGE_DIGEST
    push-to-registry: true
```
Similarly, we can generate the SBOM and attest it:

```yaml
- name: Generate SBOM
  uses: anchore/sbom-action@v0
  with:
    image: CONTAINER_IMAGE_NAME:TAG
    format: 'cyclonedx-json'
    output-file: 'sbom.cyclonedx.json'

- name: Attest SBOM
  uses: actions/attest-sbom@v2
  id: attest-sbom
  with:
    subject-name: CONTAINER_IMAGE_NAME
    subject-digest: CONTAINER_IMAGE_DIGEST
    sbom-path: 'sbom.cyclonedx.json'
    push-to-registry: true
```

The actions above will upload the two attestations in the GitHub Attestations Registry which is accessible via its API. Later on, they can be verified.