#path 
source Kocom/Kocom/path

#set ulimit open file 64000
ulimit -n 64000

#run MQTT port 1883
sudo ufw allow 1883
cd mosquitto
mosquitto -c mosquitto.conf -d
cd ~

#run MongoDB port 30000
mongod --fork --logpath db/log/log.log --logappend --port 30000 --dbpath db/data/ 

#run Rserve port 6311
sudo ufw allow 6311
sudo R CMD Rserve --no-save --RS-enable-remote &

#run SmartCloud
cd SC
. runSC.sh
cd ~

#run pdCollector
cd PD
. runPD.sh
cd ~
sleep 10

#run CEMS
cd CEMS
java -jar CEMS.jar &
cd ~

#run Dashboard port 20000
sudo ufw allow 20000
sudo R CMD BATCH shiny.R shiny.log &
disown
