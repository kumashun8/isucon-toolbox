# from kumashun8/isucon-toolbox
#
SERVICE_NAME = sample.service # systemctl status $(SERVICE_NAME)
BUILD_TARGET = build
ALP_REGEXP = '/api/sample/[0-9a-z\-]+'

restart: $(BUILD_TARGET) log.rotate restart-mysql restart-app restart-nginx # set build target on top
init: init.config init.asdf init.tools log.init
survey: survey.slowlog survey.nginx

restart-app:
	rm -f /tmp/webapp.sock
	sudo systemctl restart $(SERVICE_NAME)
	sudo systemctl status $(SERVICE_NAME) | tail -n 5

restart-nginx:
	sudo rsync -av ../conf/nginx/ /etc/nginx/
	sudo nginx -s reload
	sudo systemctl status nginx | tail -n 5

restart-mysql:
	sudo rsync -av ../conf/mysql/ /etc/mysql/
	sudo systemctl restart mysql.service
	sudo systemctl status mysql.service | tail -n 5

init.config:
	mkdir -p ../conf
	mkdir -p ../conf/nginx
	mkdir -p ../conf/mysql
	mkdir -p ../conf/nginx/sites-enabled
	mkdir -p ../conf/mysql/conf.d
	cp /etc/nginx/nginx.conf ../conf/nginx/nginx.conf
	cp /etc/nginx/sites-enabled/* ../conf/nginx/sites-enabled/
	cp /etc/mysql/conf.d/*.cnf ../conf/mysql/conf.d/

init.asdf:
	git clone https://github.com/asdf-vm/asdf.git ~/.asdf
	echo '. "/home/isucon/.asdf/asdf.sh"' > ~/.bashrc
	. ~/.bashrc

init.tools:
	sudo apt update
	sudo apt-get install -y percona-toolkit unzip
	asdf plugin add alp
	asdf install alp `asdf list-all alp | tail -1`
	asdf global alp `asdf list-all alp | tail -1`

survey.slowlog:
	sudo pt-query-digest /var/log/mysql/mysql-slow.log | \
	tee ../survey/slowlog/digest_`date +%Y%m%d%H%M%S`.txt

# need to customize regexp
survey.nginx:
	sudo cat /var/log/nginx/access.log | \
	alp json --sort=sum -r -m $(ALP_REGEXP)| \
	tee ../survey/nginx/alp_`date +%Y%m%d%H%M%S`.txt

log.init:
	sudo touch /var/log/mysql/mysql-slow.log
	sudo touch /var/log/nginx/access.log
	mkdir -p ../survey
	mkdir -p ../survey/slowlog
	mkdir -p ../survey/nginx


log.rotate:
	sudo mv /var/log/mysql/mysql-slow.log /var/log/mysql/mysql-slow.log.`date +%Y%m%d%H%M%S`
	sudo touch /var/log/mysql/mysql-slow.log
	sudo chmod 777 /var/log/mysql/mysql-slow.log
	sudo mv /var/log/nginx/access.log /var/log/nginx/access.log.`date +%Y%m%d%H%M%S`
	sudo touch /var/log/nginx/access.log

clean.all: clean.log
	rm -rf ../conf
	sudo rm -rf /home/isucon/.asdf

clean.log:
	rm -rf ../survey

# ref: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
init.git:
	type -p curl >/dev/null || (sudo apt update && sudo apt install curl -y)
	curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
	&& sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [arch=$$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y
	gh auth login
	ssh -T git@github.com

# e.g. GIT_HUB_USER_EMAIL=test@test.com GIT_HUB_USER_ID=test make config.git
config.git:
	git config --global user.email $$GIT_HUB_USER_EMAIL
	git config --global user.name $$GIT_HUB_USER_ID
	git config --global core.editor vim
	git config -l

# mysql slow-log
#
# slow_query_log = 1
# slow_query_log_file = /var/log/mysql/mysql-slow.log
# long_query_time = 0
#
#
# nginx log
# # copy in http directive
# log_format json escape=json '{"time":"$time_iso8601",'
#                             '"host":"$remote_addr",'
#                             '"port":$remote_port,'
#                             '"method":"$request_method",'
#                             '"uri":"$request_uri",'
#                             '"status":"$status",'
#                             '"body_bytes":$body_bytes_sent,'
#                             '"referer":"$http_referer",'
#                             '"ua":"$http_user_agent",'
#                             '"request_time":"$request_time",'
#                             '"response_time":"$upstream_response_time"}';
# access_log /var/log/nginx/access.log json;

