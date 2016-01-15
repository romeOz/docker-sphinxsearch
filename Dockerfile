FROM ubuntu:trusty
MAINTAINER romeOz <serggalka@gmail.com>

ENV OS_LOCALE="en_US.UTF-8" \
    OS_LANGUAGE="en_US:en" \
	SPHINX_LOG_DIR=/var/log/sphinxsearch \
	SPHINX_CONF=/etc/sphinxsearch/sphinx.conf \
	SPHINX_RUN=/run/sphinxsearch/searchd.pid \
	SPHINX_DATA_DIR=/var/lib/sphinxsearch/data

# Set the locale
RUN locale-gen ${OS_LOCALE}
ENV LANG=${OS_LOCALE} \
	LANGUAGE=${OS_LANGUAGE} \
	LC_ALL=${OS_LOCALE}

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
	&& ln -sf /dev/stdout ${SPHINX_LOG_DIR}/searchd.log \
	&& ln -sf /dev/stdout ${SPHINX_LOG_DIR}/query.log

COPY ./configs/* /etc/sphinxsearch/

EXPOSE 9312 9306
VOLUME ["${SPHINX_DATA_DIR}"]
ENTRYPOINT ["/sbin/entrypoint.sh"]