FROM lsiobase/ubuntu:focal
LABEL maintainer="RandomNinjaAtk"

ENV TITLE="raromprocessor"
ENV VERSION="0.0.007"
ENV SKYSCRAPER_PATH /usr/local/skysource
ENV RAHASHER_PATH /usr/local/RALibretro
ENV ScriptInterval=1h
ENV DeDupe=false
ENV AquireRomSets=false
ENV ConcurrentDownloadThreads=1
ENV ScrapeMetadata=false
ENV EnableUnsupportedPlatforms=true

RUN \
	echo "************ install dependencies ************" && \
	echo "************ install and upgrade packages ************" && \
	apt-get update && \
	apt-get upgrade -y && \
	apt-get install -y \
		jq \
		unzip \
		gzip \
		git \
		p7zip-full \
		curl \
		make \
		gcc \
		unrar \
		axel \
		mame-tools \
		mingw-w64 \
		python3-pip && \
	echo "************ install python packages ************" && \
	python3 -m pip install --no-cache-dir -U \
		yq \
		internetarchive && \
	echo "************ skyscraper ************" && \
	echo "************ install dependencies ************" && \
	echo "************ install packages ************" && \
	apt-get update && \
	apt-get install -y \
		build-essential \
		wget \
		qt5-default && \
	apt-get purge --auto-remove -y && \
	apt-get clean && \
	echo "************ install skyscraper ************" && \
	mkdir -p ${SKYSCRAPER_PATH} && \
	cd ${SKYSCRAPER_PATH} && \
	wget https://raw.githubusercontent.com/muldjord/skyscraper/master/update_skyscraper.sh && \
	sed -i 's/sudo //g' update_skyscraper.sh && \
	bash update_skyscraper.sh && \
	echo "************ RAHasher installation ************" && \
	git clone --recursive --depth 1 https://github.com/RetroAchievements/RALibretro.git ${RAHASHER_PATH} && \
	cd ${RAHASHER_PATH} && \
	make -f Makefile.RAHasher && \
	chmod -R 777 ${RAHASHER_PATH}
		
# copy local files
COPY root/ /
 
# set work directory
WORKDIR /config
