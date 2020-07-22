FROM ubuntu:latest

RUN apt-get update && \
    # Install Java
    apt-get install -y openjdk-8-jdk && \
    # jnius-indra requires cython which requires gcc
    apt-get install -y git wget bzip2 gcc graphviz graphviz-dev pkg-config && \
    # Dependencies required by Conda
    # See https://github.com/conda/conda/issues/1051
    apt-get install -y libsm6 libxrender1 libfontconfig1 && \
    # To address problem with gcc
    # # http://stackoverflow.com/questions/11912878/gcc-error-gcc-error-trying-to-exec-cc1-execvp-no-such-file-or-directory
    apt-get install -y --reinstall build-essential

# Set default character encoding
# See http://stackoverflow.com/questions/27931668/encoding-problems-when-running-an-app-in-docker-python-java-ruby-with-u/27931669
# See http://stackoverflow.com/questions/39760663/docker-ubuntu-bin-sh-1-locale-gen-not-found
RUN apt-get install -y locales && \
    locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8  #

# Set environment variables
ENV DIRPATH /sw
ENV BNGPATH=$DIRPATH/BioNetGen-2.4.0
ENV PATH="$DIRPATH/miniconda/bin:$PATH"
ENV KAPPAPATH=$DIRPATH/KaSim

WORKDIR $DIRPATH

# Set up Miniconda and Python dependencies
RUN cd $DIRPATH && \
    # Set up Miniconda
    wget -nv https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    chmod +x miniconda.sh && \
    bash miniconda.sh -b -p $DIRPATH/miniconda && \
    conda update -y conda && \
    # Install packages that are available via conda directly
    conda install -y -c omnia python="3.7.2" \
        qt numpy scipy sympy cython nose lxml matplotlib networkx \
        ipython pandas && \
    # Now install other Python packages via pip
    pip install --upgrade pip && \
    pip install jsonschema coverage python-coveralls boto3 doctest-ignore-unicode \
                sqlalchemy psycopg2-binary reportlab pyjnius==1.1.4 \
                python-libsbml bottle gunicorn openpyxl flask obonet \
                jinja2 ndex2==2.0.1 requests stemming nltk unidecode future pykqml \
                paths-graph protmapper gilda adeft kappy==4.0.94 pybel pysb==1.9.1 \
                objectpath rdflib pygraphviz && \
    # Download protmapper resources
    python -m protmapper.resources && \
    # Download Adeft models
    python -m adeft.download && \
    # Install BioNetGen
    wget "https://github.com/RuleWorld/bionetgen/releases/download/BioNetGen-2.4.0/BioNetGen-2.4.0-Linux.tgz" \
        -O bionetgen.tar.gz -nv && \
    tar xzf bionetgen.tar.gz

# Add and set up reading systems
# ------------------------------
# SPARSER
ENV SPARSERPATH=$DIRPATH/sparser
ADD r3.core $SPARSERPATH/r3.core
ADD save-semantics.sh $SPARSERPATH/save-semantics.sh
ADD version.txt $SPARSERPATH/version.txt
RUN chmod +x $SPARSERPATH/save-semantics.sh && \
    chmod +x $SPARSERPATH/r3.core

# REACH
# Default character encoding for Java in Docker is not UTF-8, which
# leads to problems with REACH; so we set option
# See https://github.com/docker-library/openjdk/issues/32
ENV JAVA_TOOL_OPTIONS -Dfile.encoding=UTF8
ENV REACHDIR=$DIRPATH/reach
ENV REACHPATH=$REACHDIR/reach-1.6.1-SNAPSHOT-FAT.jar
ENV REACH_VERSION=1.6.1
ADD reach-1.6.1-SNAPSHOT-FAT.jar $REACHPATH

