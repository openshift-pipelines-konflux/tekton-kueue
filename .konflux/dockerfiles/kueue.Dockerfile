ARG GO_BUILDER=registry.access.redhat.com/ubi9/go-toolset:9.7-1763038106
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:61d5ad475048c2e655cd46d0a55dfeaec182cc3faa6348cb85989a7c9e196483

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/tektoncd/tekton-kueue
COPY upstream .
COPY .konflux/patches patches/
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
COPY head HEAD


ENV GODEBUG="http2server=0"
RUN go mod download
RUN go build -tags disable_gcp -ldflags="-X 'knative.dev/pkg/changeset.rev=${CHANGESET_REV:0:7}'" -o /tmp/tekton-kueue \
    ./cmd/main.go
# RUN /bin/sh -c 'echo $CI_OPERATOR_UPSTREAM_COMMIT > /tmp/HEAD'

FROM $RUNTIME

ENV KUEUE=/tmp/tekton-kueue  \
    KO_DATA_PATH=/kodata

COPY --from=builder $KUEUE $KUEUE

LABEL \
      com.redhat.component="openshift-pipelines-rhel9-kueue" \
      name="openshift-pipelines/pipelines-rhel9-kueue" \
      version="1.16.0" \
      summary="Red Hat OpenShift Pipelines Kueue" \
      maintainer="pipelines-extcomm@redhat.com" \
      description="Red Hat OpenShift Pipelines Kueue" \
      io.k8s.display-name="Red Hat OpenShift Pipelines Kueue" \
      io.k8s.description="Red Hat OpenShift Pipelines Kueue" \
      io.openshift.tags="kueue,tekton,openshift"

RUN groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT [ "${KUEUE}" ]
