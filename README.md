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

To inspect the provenance:
```sh
docker buildx imagetools inspect image/name:tag --format "{{ json .Provenance.SLSA }}"
```

### 2. GitHub Actions native action

