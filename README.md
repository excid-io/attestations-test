## Artifact Attestations with GitHub Actions

A repo to test how attestations work in GitHub Actions. We created a very simple (Hello World) express-js server in NodeJS which we containerize and attest. For each case we present a different workflow file under .github/workflows.

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

These documents are stored in the OCI Registry along with the image.

### 2. GitHub Actions native actions

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

Preferably, we would use this method to create attestations. It is an objective way of generating provenance and SBOM attestations, since we offload the process to a specific action, which is not technology- or implementation-dependent and is interoperable.

We can also verify the attestations using the `gh` cli tool:

```sh
gh attestation verify oci://IMAGE_URI:TAG --owner ORG_NAME
```

### 3. Package manager specific options (npm)

Since we have a NodeJS project here, we can see what capabilities the relevant technology stack provides us with. With `npm`, we can now create provenance attestations when [publishing](https://docs.npmjs.com/generating-provenance-statements#publishing-packages-with-provenance-via-github-actions) a package:

```sh
npm publish --provenance --access public
```

This will package our code and upload it to the npm registry as known, and will create the provenance attestation too. In order for npm to create the provenance, this command **must** run within a CI environment such as GitHub Actions or GitLab CI.
The signature can be verified by running 

```sh
npm audit signatures
```

The command above will scan the packages for invalid/outdated signatures.

### 4. SLSA GitHub Generator

SLSA provides us with a tool (the [SLSA Generator](https://github.com/slsa-framework/slsa-github-generator)) which generates provenance attestations for us. In this project, they provide us with multiple builders, one for each programming language, to build and attest the provenance of our code.

For us, the [NodeJS builder](https://github.com/slsa-framework/slsa-github-generator/blob/main/internal/builders/nodejs/README.md) is the proper one to use, to package and attest our code.

In our workflow we need to define one `build` job which inherits a reusable workflow from the `slsa-github-generator` repo, and a `publish` step which publishes the package to nmpjs. As the [NodeJS builder](https://github.com/slsa-framework/slsa-github-generator/blob/main/internal/builders/nodejs/README.md) builder documentation states, we need the following lines in our workflow:

```yaml
jobs:
  build:
    permissions:
      id-token: write # For signing
      contents: read # For repo checkout.
      actions: read # For getting workflow run info.
    if: startsWith(github.ref, 'refs/tags/')
    uses: slsa-framework/slsa-github-generator/.github/workflows/builder_nodejs_slsa3.yml@v2.1.0
    with:
      run-scripts: "ci, test, build"
```

We define which npm scripts we want to run (based on our package.json), and SLSA's reusable workflow will do it for us. When these are run, the builder packs the code into a tarball and the provenance. These are also uploaded as job artifacts in the summary after the job is finished.

Then, we `publish` the package to npmjs with the following yaml code:

```yaml
- name: publish
      id: publish
      uses: slsa-framework/slsa-github-generator/actions/nodejs/publish@v2.1.0
      with:
        access: public
        node-auth-token: ${{ secrets.NPM_TOKEN }}
        package-name: ${{ needs.build.outputs.package-name }}
        package-download-name: ${{ needs.build.outputs.package-download-name }}
        package-download-sha256: ${{ needs.build.outputs.package-download-sha256 }}
        provenance-name: ${{ needs.build.outputs.provenance-name }}
        provenance-download-name: ${{ needs.build.outputs.provenance-download-name }}
        provenance-download-sha256: ${{ needs.build.outputs.provenance-download-sha256 }}
```

When we want to install the package with `npm install pkg_name` we can run `npm audit signatures` to verify its signature.
