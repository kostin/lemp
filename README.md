# lemp6
```
mkdir -p /opt/scripts; \
yum install -y rsync unzip wget \
&& cd /tmp \
&& wget --no-check-certificate -O /tmp/master.zip \
   https://github.com/kostin/lemp6/archive/master.zip \
&& unzip -o master.zip \
&& rsync -a /tmp/lemp6/ /opt/scripts/ \
&& chmod +x /opt/scripts/*.sh \
&& chmod +x /opt/scripts/*/*.sh \
&& /opt/scripts/install.sh
```
