FROM python:2.7.9
MAINTAINER Ariel Núñez<ariel@terranodo.io>

ENV GDAL_VERSION 2.1.3

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# This section is borrowed from the official Django image but adds GDAL and others
RUN apt-get update && apt-get install -y \
    gcc \
    gettext \
    postgresql-client libpq-dev \
    sqlite3 \
    python-psycopg2 \
    python-imaging python-lxml \
    python-dev \
    python-ldap \
    libgeos-dev libmemcached-dev libsasl2-dev zlib1g-dev \
    python-pylibmc \
    --no-install-recommends && rm -rf /var/lib/apt/lists/*

# install latest GDAL since version on Jessie stable is outdated (1.10.1)
RUN mkdir -p /usr/src/app/gdal
#ADD http://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz /usr/src/app/gdal/
RUN wget -O /usr/src/app/gdal/gdal-${GDAL_VERSION}.tar.gz http://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz && \
    cd /usr/src/app/gdal/ && tar -xzf gdal-${GDAL_VERSION}.tar.gz && cd gdal-${GDAL_VERSION} && \
    ./configure --with-python && \
    make -j $(grep --count ^processor /proc/cpuinfo) && make install && ldconfig && \
    rm -Rf /usr/src/app/gdal/*

COPY wait-for-postgres.sh /usr/bin/wait-for-postgres
RUN chmod +x /usr/bin/wait-for-postgres

# To understand the next section (the need for requirements.txt and setup.py)
# Please read: https://packaging.python.org/requirements/

# python-gdal does not seem to work, let's install manually the version that is
# compatible with the provided libgdal-dev
#RUN pip install GDAL==1.10 --global-option=build_ext --global-option="-I/usr/include/gdal"
RUN pip install GDAL==2.1.3 --global-option=build_ext --global-option="-I/usr/include/gdal"

# Copy the requirements first to avoid having to re-do it when the code changes.
# Requirements in requirements.txt are pinned to specific version
# usually the output of a pip freeze
COPY requirements.txt /usr/src/app/
RUN pip install --no-cache-dir -r requirements.txt

# Update the requirements from the local env in case they differ from the pre-built ones.
ONBUILD COPY requirements.txt /usr/src/app/
ONBUILD RUN pip install --no-cache-dir -r requirements.txt

ONBUILD COPY . /usr/src/app/
ONBUILD RUN pip install --no-deps --no-cache-dir -e /usr/src/app/

EXPOSE 8000
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
