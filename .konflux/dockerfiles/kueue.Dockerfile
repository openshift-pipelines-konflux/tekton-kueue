ARG GO_BUILDER=registry.access.redhat.com/ubi9/go-toolset:9.6-1760420453
ARG RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal@sha256:34880b64c07f28f64d95737f82f891516de9a3b43583f39970f7bf8e4cfa48b7

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
