FROM ubuntu:trusty
MAINTAINER romeOz <serggalka@gmail.com>

ENV SPHINX_LOCALE="en_US.UTF-8" \
	SPHINX_LOGDIR=/var/log/sphinxsearch \
	SPHINX_CONF=/etc/sphinxsearch/sphinx.conf \
	SPHINX_RUN=/run/sphinxsearch/searchd.pid \
	SPHINX_DATADIR=/var/lib/sphinxsearch/data

# Set the locale
RUN locale-gen ${SPHINX_LOCALE}
ENV LANG=${SPHINX_LOCALE} \
	LANGUAGE=en_US:en \
	LC_ALL=${SPHINX_LOCALE}

COPY ./entrypoint.sh /sbin/entrypoint.sh

RUN	buildDeps='software-properties-common python-software-properties' \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends \
	&& add-apt-repository -y ppa:builds/sphinxsearch-rel22 \
	&& apt-get update \
	&& apt-get install -y sphinxsearch \
	&& mv -f /etc/sphinxsearch/sphinx.conf /etc/sphinxsearch/origin.sphinx.conf \
	&& apt-get purge -y --auto-remove $buildDeps \
	&& rm -rf /var/lib/apt/lists/* \
    && chmod 755 /sbin/entrypoint.sh \
	# Forward sphinx logs to docker log collector
	&& ln -sf /dev/stdout ${SPHINX_LOGDIR}/searchd.log \
	&& ln -sf /dev/stdout ${SPHINX_LOGDIR}/query.log

COPY ./sphinx.conf ${SPHINX_CONF}

EXPOSE 9312 9306
VOLUME ["${SPHINX_DATADIR}"]
ENTRYPOINT ["/sbin/entrypoint.sh"]