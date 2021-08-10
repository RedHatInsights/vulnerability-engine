FROM registry.access.redhat.com/ubi8/ubi-minimal

ARG PG_REPO=https://download.postgresql.org/pub/repos/yum/12/redhat/rhel-8-x86_64/
ARG PG_RPM=postgresql12-12.2-2PGDG.rhel8.x86_64.rpm
ARG PG_LIBS_RPM=postgresql12-libs-12.2-2PGDG.rhel8.x86_64.rpm
ARG PG_REPACK_RPM=pg_repack12-1.4.6-1.rhel8.x86_64.rpm
ADD /manager/RPM-GPG-KEY-PGDG /etc/pki/rpm-gpg/
RUN microdnf install python38 which shadow-utils diffutils systemd libicu git-core && microdnf clean all && \
    curl -o /tmp/${PG_RPM} ${PG_REPO}${PG_RPM} && \
    curl -o /tmp/${PG_LIBS_RPM} ${PG_REPO}${PG_LIBS_RPM} && \
    curl -o /tmp/${PG_REPACK_RPM} ${PG_REPO}${PG_REPACK_RPM} && \
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-PGDG && \
    rpm -K /tmp/${PG_RPM} /tmp/${PG_LIBS_RPM} /tmp/${PG_REPACK_RPM} && \
    rpm -ivh /tmp/${PG_RPM} /tmp/${PG_LIBS_RPM} /tmp/${PG_REPACK_RPM} && \
    rm /tmp/${PG_RPM} /tmp/${PG_LIBS_RPM} /tmp/${PG_REPACK_RPM}

RUN ln -s /usr/pgsql-12/bin/pg_repack /bin/pg_repack

# for manager purposes
RUN mkdir -p /tmp/prometheus_multiproc
ENV prometheus_multiproc_dir=/tmp/prometheus_multiproc

# minimal schema required by application, used for waiting in services until DB migration is finished
ENV MINIMAL_SCHEMA=92

WORKDIR /engine

ADD /Pipfile*        /engine/

ENV LC_ALL=C.utf8
ENV LANG=C.utf8
ARG PIPENV_CHECK=1
ARG PIPENV_PYUP_API_KEY=""
RUN pip3 install --upgrade pip && \
    pip3 install --upgrade pipenv && \
    pipenv install --ignore-pipfile --deploy --system && \
    if [ "${PIPENV_CHECK}" == 1 ] ; then pipenv check --system -i 39462 -i 41002; fi

RUN adduser --gid 0 -d /engine --no-create-home insights

# for manager purposes
RUN chown -R insights:0 /tmp/prometheus_multiproc && \
    chgrp -R 0 /tmp/prometheus_multiproc && \
    chmod -R g=u /tmp/prometheus_multiproc

USER insights

EXPOSE 8000

ADD entrypoint.sh                          /engine/
ADD manager.healthz.spec.yaml              /engine/
ADD manager.admin.spec.yaml                /engine/
ADD /database/upgrade/dbupgrade.sh         /engine/
ADD /metrics/*.py                          /engine/metrics/
ADD /advisor_listener/*.py                 /engine/advisor_listener/
ADD /taskomatic/*.py                       /engine/taskomatic/
ADD /taskomatic/jobs/*.py                  /engine/taskomatic/jobs/
ADD /vmaas_sync/*.py                       /engine/vmaas_sync/
ADD /database/*.py                         /engine/database/
ADD /database/upgrade/*.py                 /engine/database/upgrade/
ADD /database/schema/*.sql                 /engine/database/schema/
ADD /database/schema/upgrade_scripts/*.sql /engine/database/schema/upgrade_scripts/
ADD /evaluator/*.py                        /engine/evaluator/
ADD /listener/*.py                         /engine/listener/
ADD manager.spec.yaml                      /engine/
ADD /common/*.py                           /engine/common/
ADD /manager/*.py                          /engine/manager/
