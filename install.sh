
cd dependencies
WD=`pwd`

if [ ! -d PROMISING ]
then
    echo ----- Grabbing PROMISING source code ------
    git clone https://github.com/kcanderson/PROMISING.git
    echo ----- Building PROMISING ------
    cd PROMISING
    ./configure
    make
fi

cd $WD

if [ ! -f lein ]
then
    echo ----- Grabbing leiningen ------
    curl https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein > lein
    chmod ugo+x lein
fi

if [ ! -d promising_helper ]
then
    echo ----- Grabbing PROMISING helper tool ------
    git clone https://github.com/kcanderson/promising_helper.git
    cd promising_helper
    echo ----- Building uberjar for PROMISING helper tool ------
    ../lein uberjar
fi

cd $WD

echo ----- Grabbing other large files ------
# Grab large files from GitHub release
GITHUB_RELEASE_URL=https://github.com/kcanderson/reproduce_promising/releases/download/v0.0.1/
ANNOTATIONS_FILENAME=Homo_sapiens.GRCh37.70.with.entrezid.gtf
ANNOTATIONS_LOCAL_PATH=../annotations/${ANNOTATIONS_FILENAME}
if [[ ! -f ${ANNOTATIONS_LOCAL_PATH} ]]
then
    echo ----- Grabbing annotations GTF ------
    ls -lh ../annotations
    curl -L ${GITHUB_RELEASE_URL}/${ANNOTATIONS_FILENAME} > ${ANNOTATIONS_LOCAL_PATH}
fi

# Grab networks from GitHub release
STRING_FILENAME=9606.protein.links.detailed.v10.txt
STRING_LOCAL_PATH=../networks_source/${STRING_FILENAME}
if [[ ! -f ${STRING_LOCAL_PATH} ]]
then
    echo ----- Grabbing STRING network ------
    ls -lh ../networks_source
    curl -L ${GITHUB_RELEASE_URL}/${STRING_FILENAME} > ${STRING_LOCAL_PATH}
fi

PF_FILENAME=main_FAN.csv
PF_LOCAL_PATH=../networks_source/${PF_FILENAME}
if [[ ! -f ${PF_LOCAL_PATH} ]]
then
    echo ----- Grabbing Prix Fixe network ------
    curl -L ${GITHUB_RELEASE_URL}/${PF_FILENAME} > ${PF_LOCAL_PATH}
fi

# Install R packages
echo ----- Installing R packages -----
Rscript ../install_r_packages.r
