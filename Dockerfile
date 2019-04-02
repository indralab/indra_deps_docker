FROM ubuntu:latest

# The add-apt-repository command depends on software-properties-common
# and python-software-properties; these require apt-get update to be called first
# http://lifeonubuntu.com/ubuntu-missing-add-apt-repository-command/
RUN apt-get update && \
    apt-get install -y software-properties-common debconf-utils && \
    add-apt-repository -y ppa:webupd8team/java && \
    apt-get update && \
    # jnius-indra requires cython which requires gcc
    apt-get install -y git wget bzip2 gcc && \
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
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle
ENV BNGPATH=$DIRPATH/BioNetGen-2.3.1
ENV PATH="$DIRPATH/miniconda/bin:$PATH"
ENV KAPPAPATH=$DIRPATH/KaSim
# Default character encoding for Java in Docker is not UTF-8, which
# leads to problems with REACH; so we set option
# See https://github.com/docker-library/openjdk/issues/32
ENV JAVA_TOOL_OPTIONS -Dfile.encoding=UTF8
# These are used by INDRA when running REACH
ENV REACHDIR=$DIRPATH/reach
ENV REACHPATH=$REACHDIR/reach-61059a-biores-e9ee36.jar
ENV REACH_VERSION=1.3.3-61059a-biores-e9ee36
ENV SPARSERPATH=$DIRPATH/sparser

WORKDIR $DIRPATH

ADD r3.core $SPARSERPATH/r3.core
ADD save-semantics.sh $SPARSERPATH/save-semantics.sh
ADD version.txt $SPARSERPATH/version.txt

# Install Java
RUN echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | \
                                               debconf-set-selections && \
    chmod +x $SPARSERPATH/save-semantics.sh && \
    chmod +x $SPARSERPATH/r3.core && \
    apt-get install -y oracle-java8-installer && \
    cd /var/lib/dpkg/info && \
    sed -i 's|JAVA_VERSION=8u171|JAVA_VERSION=8u181|' oracle-java8-installer.* && \
    sed -i 's|PARTNER_URL=http://download.oracle.com/otn-pub/java/jdk/8u171-b11/512cd62ec5174c3487ac17c61aaa89e8/|PARTNER_URL=http://download.oracle.com/otn-pub/java/jdk/8u181-b13/96a7b8442fe848ef90c96a2fad6ed6d1/|' oracle-java8-installer.* && \
    sed -i 's|SHA256SUM_TGZ="b6dd2837efaaec4109b36cfbb94a774db100029f98b0d78be68c27bec0275982"|SHA256SUM_TGZ="1845567095bfbfebd42ed0d09397939796d05456290fb20a83c476ba09f991d3"|' oracle-java8-installer.* && \
    sed -i 's|J_DIR=jdk1.8.0_171|J_DIR=jdk1.8.0_181|' oracle-java8-installer.* && \
    apt-get update && \
    update-java-alternatives -s java-8-oracle && \
    apt-get install -y oracle-java8-set-default && \
    cd $DIRPATH && \
    # Install SBT
    # http://stackoverflow.com/questions/13711395/install-sbt-on-ubuntu
    # (Note that the instructions at
    # http://www.scala-sbt.org/release/docs/Installing-sbt-on-Linux.html
    # did not work)
    # wget -nv http://apt.typesafe.com/repo-deb-build-0002.deb && \
    # dpkg -i repo-deb-build-0002.deb && \
    # apt-get update && \
    # apt-get install -y sbt && \
    # Fix error with missing sbt launcher
    # http://stackoverflow.com/questions/36234193/cannot-build-sbt-project-due-to-launcher-version
    # wget http://dl.bintray.com/typesafe/ivy-releases/org.scala-sbt/sbt-launch/0.13.13/sbt-launch.jar -P /root/.sbt/.lib/0.13.13 && \
    # Get and build the latest REACH
    # git clone https://github.com/clulab/reach.git && \
    #cd reach && \
    #git checkout 735b930f5ed2ddd1b7f9ce && \
    #echo 'mainClass in assembly := Some("org.clulab.reach.RunReachCLI")' >> build.sbt && \
    #sbt assembly && \
    #cd ../ && \
    wget -nv http://sorger.med.harvard.edu/data/bachman/reach-61059a-biores-e9ee36.jar -P $REACHDIR && \
    # Install packages via miniconda
    apt-get install -y python && \
    wget -nv https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    chmod +x miniconda.sh && \
    bash miniconda.sh -b -p $DIRPATH/miniconda && \
    conda update -y conda && \
    # For the time being qt needs to be set to version 4, and matplotlib to 1.5
    # See https://github.com/ContinuumIO/anaconda-issues/issues/1068
    apt-get install -y graphviz && \
    conda install -y -c omnia python="3.7.2" qt numpy scipy sympy cython nose \
                                           lxml matplotlib networkx pygraphviz && \
    pip install --upgrade pip && \
    pip install jsonschema coverage python-coveralls boto3 pandas doctest-ignore-unicode \
                sqlalchemy psycopg2 pgcopy reportlab && \
    pip install git+https://github.com/kivy/pyjnius.git && \
    # PySB and dependencies
    wget -nv "http://www.csb.pitt.edu/Faculty/Faeder/?smd_process_download=1&download_id=142" \
                                            -O BioNetGen.tar.gz && \
    tar xzf BioNetGen.tar.gz && \
    pip install pysb pybel && \
    # Install Kappa and API dependencies
    pip install python-libsbml bottle gunicorn openpyxl flask && \
    pip install git+https://github.com/ndexbio/ndex2-client.git && \
    pip install git+https://github.com/indralab/protmapper.git && \
    python -m protmapper.resources && \
    wget -nv http://sorger.med.harvard.edu/data/bgyori/kappy-4.0.0rc1-cp37-cp37m-linux_x86_64.whl && \
    pip install kappy-4.0.0rc1-cp37-cp37m-linux_x86_64.whl
