
cd dependencies
if [ ! -d PROMISING ]
then
    git clone https://github.com/kcanderson/PROMISING.git
    cd PROMISING
    ./configure
    make
    cd ..
fi

if [ ! -f lein ]
then
    curl https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein > lein
    chmod ugo+x lein
fi

if [ ! -d promising_helper ]
then
    git clone https://github.com/kcanderson/promising_helper.git
    cd promising_helper
    ../lein uberjar
    cd ..
fi

# Grab large files from GitHub release
GITHUB_RELEASE_URL=https://github.com/kcanderson/reproduce_promising/releases/download/v0.0.1/
ANNOTATIONS_FILENAME=Homo_sapiens.GRCh37.70.with.entrezid.gtf
ANNOTATIONS_LOCAL_PATH=../annotations/${ANNOTATIONS_FILENAME}
if [[ ! -f ${ANNOTATIONS_LOCAL_PATH} ]]
then
    curl -L ${GITHUB_RELEASE_URL}/${ANNOTATIONS_FILENAME} > ${ANNOTATIONS_LOCAL_PATH}
fi

# Grab networks from GitHub release
STRING_FILENAME=9606.protein.links.detailed.v10.txt
STRING_LOCAL_PATH=../networks_source/${STRING_FILENAME}
if [[ ! -f ${STRING_LOCAL_PATH} ]]
then
    curl -L ${GITHUB_RELEASE_URL}/${STRING_FILENAME} > ${STRING_LOCAL_PATH}
fi

PF_FILENAME=main_FAN.csv
PF_LOCAL_PATH=../networks_source/${PF_FILENAME}
if [[ ! -f ${PF_LOCAL_PATH} ]]
then
    curl -L ${GITHUB_RELEASE_URL}/${PF_FILENAME} > ${PF_LOCAL_PATH}
fi
