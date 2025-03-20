## Artifact Attestations with GitHub Actions

A repo to test how attestations work in GitHub Actions. We created a very simple (Hello World) express-js server in NodeJS which we containerize and attest.

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

In GitHub Actions this is done with the docker-build-push action:
```yaml
- name: Build and push Docker image
      uses: docker/build-push-action@v6.15.0
      id: build-and-push
      with:
        tags: ${{ steps.meta.outputs.tags }}
        annotations: ${{ steps.meta.outputs.annotations }}
        push: true
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        provenance: true
        sbom: true
```

### 2. GitHub Actions native action

