ARG GO_BUILDER=registry.access.redhat.com/ubi9/go-toolset:9.7-1762230058
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:2ddd6e10383981c7d10e4966a7c0edce7159f8ca91b1691cafabc78bae79d8f8

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
