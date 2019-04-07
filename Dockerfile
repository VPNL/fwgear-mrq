# Create Docker container that can run QMR analysis.

# Start with the Matlab r2017b runtime container
FROM  flywheel/matlab-mcr:v93.1

MAINTAINER Michael Perry <lmperry@stanford.edu>


############################
# Install dependencies
ENV LD_LIBRARY_PATH ''
RUN apt-get update && apt-get install -y \
    xvfb \
    xfonts-100dpi \
    xfonts-75dpi \
    xfonts-cyrillic \
    python \
    unzip \
    zip \
    wget && \
    wget -O- http://neuro.debian.net/lists/xenial.us-ca.full | tee /etc/apt/sources.list.d/neurodebian.sources.list && \
    apt-key adv --recv-keys --keyserver hkp://pool.sks-keyservers.net:80 0xA5D32F012649A5A9 && \
    apt-get update -qq && \
    apt-get install -y fsl-core ants && \
    chmod +x /etc/fsl/5.0/fsl.sh

# Configure the ENV
ENV ANTSPATH=/usr/lib/ants
ENV DISPLAY=:1.0
ENV FSLMULTIFILEQUIT=TRUE
ENV POSSUMDIR=/usr/share/fsl/5.0
ENV LD_LIBRARY_PATH=/usr/lib/fsl/5.0:/usr/lib:/usr/lib/x86_64-linux-gnu:/opt/mcr/v93/runtime/glnxa64:/opt/mcr/v93/bin/glnxa64:/opt/mcr/v93/sys/os/glnxa64:/opt/mcr/v93/sys/opengl/lib/glnxa64
ENV PATH=/usr/lib/fsl/5.0:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV FSLTCLSH=/usr/bin/tclsh
ENV FSLMACHINELIST=
ENV FSLREMOTECALL=
ENV FSLWISH=/usr/bin/wish
ENV FSLBROWSER=/etc/alternatives/x-www-browser
ENV FSLDIR=/usr/share/fsl/5.0
ENV FSLLOCKDIR=
ENV FSLOUTPUTTYPE=NIFTI_GZ
RUN python -c 'import os, json; f = open("/dockerenv.json", "w"); json.dump(dict(os.environ), f)'

# Make directory for flywheel spec (v0)
ENV FLYWHEEL /flywheel/v0
RUN mkdir -p ${FLYWHEEL}

# ADD the Matlab Stand-Alone (MSA) into the container.
# Must be compiled prior to gear build - this will fail otherwise
COPY build/bin/fwgear_mrq \
     build/bin/run_fwgear_mrq.sh \
     /usr/local/bin/

# Copy and configure run script and metadata code
COPY fix_links.sh /usr/local/bin/fix_links.sh
RUN chmod +x /usr/local/bin/fix_links.sh
COPY run.py ${FLYWHEEL}/run
COPY manifest.json ${FLYWHEEL}/manifest.json
RUN chmod +x ${FLYWHEEL}/run

# Configure entrypoint
ENTRYPOINT ["/flywheel/v0/run"]
