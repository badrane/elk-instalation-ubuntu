#! /bin/bash

if [ $EUID -ne 0 ];then
	echo "doit être exécuté en ROOT !"
	exit
fi

read -p "[!] Entrer l'adresse IP du serveur => " ip_addr

apt update -y 
apt upgrade -y
apt install openjdk-11-jdk wget apt-transport-https curl gnupg2 -y
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-7.x.list
apt-get update -y
apt-get install elasticsearch -y
systemctl start elasticsearch
systemctl enable elasticsearch
curl -X GET http://localhost:9200

apt-get install logstash -y

IFS=$'\n'
logstash_conf="# Fichier de configuration de configuration Logstash pour l'input Filebeat et output Elasticsearch \n
input {  \n
	beats {  \n 
		port => 5044 \n
	} \n
} \n
\n
# Parser les messages syslog \n
\n
filter { \n
	if [type] == 'syslog' { \n
		grok { \n
			match => { 'message' => '%{SYSLOGINE}' } \n
		} \n
		date { \n
			match => [ 'timestamp', 'MMM d HH:mm:ss', 'MMM dd HH:mm:ss' ] \n
		} \n
	} \n
} \n"


echo -e $logstash_conf > /etc/Logstash/conf.d/logstash.conf

systemctl start logstash
systemctl enable logstash

apt install kibana -y

echo -e 'elasticsearch.hosts: ["http://localhost:9200"]' >> /etc/kibana/kibana.yml
sed -i 's|#server.host: "localhost"|server.host: '"$ip_addr"'|g' /etc/kibana/kibana.yml

systemctl start kibana
systemctl enable kibana

apt install filebeat -y

sed -i '176 s/^/#/' /etc/filebeat/filebeat.yml
sed -i '178 s/^/#/' /etc/filebeat/filebeat.yml

sed -i '189 s/# *//' /etc/filebeat/filebeat.yml
sed -i '191 s/# *//' /etc/filebeat/filebeat.yml


systemctl start filebeat
systemctl enable filebeat

filebeat module enable system

filebeat setup --index-management -E output.logstash.enabled=false -E 'output.elasticsearch.hosts=["localhost:9200"]'

echo "Go to http://$ip_addr:5601 to access Kibana interface :)"
