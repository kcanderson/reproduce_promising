
cd dependencies
git clone https://github.com/kcanderson/PROMISING.git

cd PROMISING
./configure
make

cd ..

curl https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein
git clone https://github.com/kcanderson/promising_helper.git
cd promising_helper
lein uberjar

