#sudo add-apt-repository ppa:webupd8team/java #add repository for java
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list

sudo apt-get update -y
sudo apt-get install git gdebi -y #install git
sudo apt-get install libssl-dev -y
sudo apt-get install uuid-dev -y
sudo apt-get install libkrb5-dev -y
sudo apt-get install oracle-java7-installer -y #install jdk 1.7

curl -sL https://deb.nodesource.com/setup | sudo bash -
sudo apt-get install -y nodejs #install nodejs
sudo apt-get install -y build-essential

sudo apt-get install -y mongodb-org #install mongodb
#sudo apt-get install -y mongodb #install mongodb

sudo wget https://cran.r-project.org/bin/linux/ubuntu/trusty/r-base-core_3.2.1-3trusty0_amd64.deb #download r-base
sudo gdebi -n r-base-core_3.2.1-3trusty0_amd64.deb #install r-base dependancy
sudo apt-get install r-base-dev -y 
sudo apt-get install r-cran-rserve -y  #install Rserve
sudo rm -r -f Kocom
git clone https://github.com/ljinsup/Kocom.git #clone the kocom repository

mv Kocom/Kocom/mosquitto mosquitto  #build mosquitto
cd mosquitto
make clean
sudo make install
sudo useradd  mosquitto #add user mosquitto
sudo groupadd mosquitto
cd ~

mv Kocom/Kocom/R_Pkgs/* ~
sudo R CMD BATCH installpkgs1.R #install R Packages
sudo apt-get install r-cran-rjava -y #install Rjava
sudo apt-get install liblzma-dev -y
sudo R CMD javareconf #Rjava config
sudo R CMD BATCH installpkgs2.R log #install R Packages
cd /usr/lib/R/bin/
sudo ln -sf ../site-library/Rserve/libs/Rserve #Rserve config
sudo ln -sf ../site-library/Rserve/libs/Rserve.dbg
cd ~

source Kocom/Kocom/path #path
mv Kocom/Kocom/CEMS CEMS #move Analysis module

sudo npm install forever -g

mv Kocom/Kocom/SC SC
cd SC
sudo npm install --save
cd ~

mv Kocom/Kocom/PD PD
cd PD
sudo npm install --save
cd ~
