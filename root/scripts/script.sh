#!/usr/bin/with-contenv bash


Process_Roms () {
	Region="$1"
	RegionGrep="$1"
	# Process ROMs with RAHasher
	if [ "$Region" = "Other" ]; then
		RegionGrep="."
	fi
	find /input/$folder -type f | grep -i "$RegionGrep" | sort | while read LINE;
	do
		Rom="$LINE"
		if [ -d "/tmp/rom_storage" ]; then
			rm -rf "/tmp/rom_storage"
		fi
		TMP_DIR="/tmp/rom_storage"
		mkdir -p "$TMP_DIR"
		rom="$Rom"

		RomFilename="${rom##*/}"
		RomExtension="${filename##*.}"

		echo "$ConsoleName :: $RomFilename :: $Region :: Processing..."
		RaHash=""
		if [ "$SkipUnpackForHash" = "false" ]; then
			case "$rom" in
				*.zip|*.ZIP)
					uncompressed_rom="$TMP_DIR/$(unzip -Z1 "$rom" | head -1)"
					unzip -o -d "$TMP_DIR" "$rom" >/dev/null
					if [ "$SkipRahasher" = "false" ]; then
						RaHash=$(/usr/local/RALibretro/bin64/RAHasher $ConsoleId "$uncompressed_rom") || ret=1
					fi
					;;
				*.7z|*.7Z)
					uncompressed_rom="$TMP_DIR/$(7z l -slt "$rom" | sed -n 's/^Path = //p' | sed '2q;d')"
					7z e -y -bd -o"$TMP_DIR" "$rom" >/dev/null
					if [ "$SkipRahasher" = "false" ]; then
						RaHash=$(/usr/local/RALibretro/bin64/RAHasher $ConsoleId "$uncompressed_rom") || ret=1
					fi
					;;
				*.chd|*.CHD)
					if [ "$SkipRahasher" = "false" ]; then
						if [ "$folder" = "dreamcast" ]; then
							ExtractedExtension=gdi
						elif [ "$folder" = "segacd" ]; then
							ExtractedExtension=gdi
						else
							ExtractedExtension=cue
						fi
						echo "$ConsoleName :: $RomFilename :: CHD Detected"
						echo "$ConsoleName :: $RomFilename :: Extracting CHD for Hashing"
						chdman extractcd -i "$rom" -o "$TMP_DIR/game.$ExtractedExtension"
						RaHash=$(/usr/local/RALibretro/bin64/RAHasher $ConsoleId "$TMP_DIR/game.$ExtractedExtension") || ret=1
					fi
					;;
				*)
					if [ "$SkipRahasher" = "false" ]; then
						RaHash=$(/usr/local/RALibretro/bin64/RAHasher $ConsoleId "$rom") || ret=1
					fi
					;;
			esac

		    if [[ $ret -ne 0 ]]; then
				rm -f "$uncompressed_rom"
		    fi
		else
			RaHash=$(/usr/local/RALibretro/bin64/RAHasher $ConsoleId "$rom")
		fi

		
		if [ "$SkipRahasher" = "false" ]; then
			echo "$ConsoleName :: $RomFilename :: Hash Found :: $RaHash"
			echo "$ConsoleName :: $RomFilename :: Matching To RetroAchievements.org DB"
			if cat "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json" | jq -r .[] | grep -i "\"$RaHash\"" | read; then
				GameId=$(cat "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json" | jq -r .[] | grep -i "\"$RaHash\"" | cut -d ":" -f 2 | sed "s/\ //g" | sed "s/,//g")
				echo "$ConsoleName :: $RomFilename :: Match Found :: Game ID :: $GameId"
				Skip="false"
				if [ "$DeDupe" = "true" ]; then
					if [ -f "/output/$ConsoleDirectory/$RomFilename" ]; then
						echo "$ConsoleName :: $RomFilename :: Previously Imported, skipping..."
						Skip="true"
					elif [ -f "/config/logs/matched_games/$ConsoleDirectory/$GameId" ]; then
						echo "$ConsoleName :: $RomFilename :: Duplicate Found, skipping..."
						Skip="true"
					fi
				else
					echo "DeDuping process disabled..."
				fi
				if [ "$Skip" = "false" ]; then
					if [ ! -d /output/$ConsoleDirectory ]; then
						echo "$ConsoleName :: $RomFilename :: Creating Console Directory \"/output/$ConsoleDirectory\""
						mkdir -p /output/$ConsoleDirectory
						chmod 777 /output/$ConsoleDirectory
						chown abc:abc /output/$ConsoleDirectory
					fi
					if [ ! -f "/output/$ConsoleDirectory/$RomFilename" ]; then
						echo "$ConsoleName :: $RomFilename :: Copying ROM to \"/output/$ConsoleDirectory\""
						cp "$rom" "/output/$ConsoleDirectory"/
					else
						echo "$ConsoleName :: $RomFilename :: Previously Imported, skipping..."
					fi
				fi
				if [ ! -d "/config/logs/matched_games/$ConsoleDirectory" ]; then 
					mkdir -p "/config/logs/matched_games/$ConsoleDirectory"
					chown abc:abc "/config/logs/matched_games/$ConsoleDirectory"
				fi
				touch "/config/logs/matched_games/$ConsoleDirectory/$GameId"
			else
				echo "$ConsoleName :: $RomFilename :: ERROR :: Not Found on RetroAchievements.org DB"
			fi
		else
			if [ ! -d /output/$ConsoleDirectory ]; then
				echo "$ConsoleName :: $RomFilename :: Creating Console Directory \"/output/$ConsoleDirectory\""
				mkdir -p /output/$ConsoleDirectory
				chmod 777 /output/$ConsoleDirectory
				chown abc:abc /output/$ConsoleDirectory
			fi
			if [ ! -f "/output/$ConsoleDirectory/$RomFilename" ]; then
				echo "$ConsoleName :: $RomFilename :: Copying ROM to \"/output/$ConsoleDirectory\""
				cp "$rom" "/output/$ConsoleDirectory"/
			else
				echo "$ConsoleName :: $RomFilename :: Previously Imported, skipping..."
			fi
		fi
		# backup processed ROM to /backup
		# create backup directories/path that matches input path
		if [ ! -d "/backup/$(dirname "${Rom:7}")" ]; then
			echo "$ConsoleName :: $RomFilename :: Creating Missing Backup Folder :: /backup/$(dirname "${Rom:7}")"
			mkdir -p "/backup/$(dirname "${Rom:7}")"
			chmod 777 "/backup/$(dirname "${Rom:7}")"
			chown abc:abc "/backup/$(dirname "${Rom:7}")"
		fi
		# copy ROM from /input to /backup
		if [ ! -f "/backup/${Rom:7}" ]; then
			echo "$ConsoleName :: $RomFilename :: Backing up ROM to: /backup/$(dirname "${Rom:7}")"
			cp "$Rom" "/backup/${Rom:7}"
			chmod 666 "/backup/${Rom:7}"
			chown abc:abc "/backup/${Rom:7}"
		fi
		# remove ROM from input
		echo "$ConsoleName :: $RomFilename :: Removing ROM from /input"
		rm "$Rom"
		
	done
}

for folder in $(ls /input); do
	ConsoleId=""
	ConsoleName=""
	ArchiveUrl=""
	SkipUnpackForHash="false"
	if echo "$folder" | grep "^amstradcpc$" | read; then
		ConsoleId=37
		ConsoleName="Amstrad CPC"
		ConsoleDirectory="amstradcpc"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Amstrad - CPC.zip"
	fi
	
	if echo "$folder" | grep "^megadrive$" | read; then
		ConsoleId=1
		ConsoleName="Sega Mega Drive"
		ConsoleDirectory="megadrive"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Sega - Mega Drive - Genesis.zip"
	fi

	if echo "$folder" | grep "^n64$" | read; then
		ConsoleId=2
		ConsoleName="Nintendo 64"
		ConsoleDirectory="n64"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Nintendo - Nintendo 64.zip"
	fi

	if echo "$folder" | grep "^snes$" | read; then
		ConsoleId=3
		ConsoleName="Super Nintendo Entertainment System"
		ConsoleDirectory="snes"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Nintendo - Super Nintendo Entertainment System.zip"
	fi

	if echo "$folder" | grep "^gb$" | read; then
		ConsoleId=4
		ConsoleName="GameBoy"
		ConsoleDirectory="gb"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Nintendo - Game Boy.zip"
	fi

	if echo "$folder" | grep "^gba$" | read; then
		ConsoleId=5
		ConsoleName="GameBoy Advance"
		ConsoleDirectory="gba"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Nintendo - Game Boy Advance.zip"
	fi

	if echo "$folder" | grep "^gbc$" | read; then
		ConsoleId=6
		ConsoleName="GameBoy Color"
		ConsoleDirectory="gbc"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Nintendo - Game Boy Color.zip"
	fi

	if echo "$folder" | grep "^nes$" | read; then
		ConsoleId=7
		ConsoleName="Nintendo Entertainment System"
		ConsoleDirectory="nes"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Nintendo - Nintendo Entertainment System.zip"
	fi

	if echo "$folder" | grep "^pcengine$" | read; then
		ConsoleId=8
		ConsoleName="PC Engine"
		ConsoleDirectory="pcengine"
	fi

	if echo "$folder" | grep "^segacd$" | read; then
		ConsoleId=9
		ConsoleName="Sega CD"
		ConsoleDirectory="segacd"
		ArchiveUrl="https://archive.org/compress/SEGACD_CHD_PLUS"
	fi

	if echo "$folder" | grep "^sega32x$" | read; then
		ConsoleId=10
		ConsoleName="Sega 32X"
		ConsoleDirectory="sega32x"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Sega - 32X.zip"
	fi

	if echo "$folder" | grep "^mastersystem$" | read; then
		ConsoleId=11
		ConsoleName="Sega Master System"
		ConsoleDirectory="mastersystem"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Sega - Master System - Mark III.zip"
	fi

	if echo "$folder" | grep "^psx$" | read; then
		ConsoleId=12
		ConsoleName="PlayStation"
		ConsoleDirectory="psx"
	fi

	if echo "$folder" | grep "^atarilynx$" | read; then
		ConsoleId=13
		ConsoleName="Atari Lynx"
		ConsoleDirectory="atarilynx"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Atari - Lynx.zip"
	fi

	if echo "$folder" | grep "^ngpc$" | read; then
		ConsoleId=14
		ConsoleName="SNK Neo Geo Pocket Color"
		ConsoleDirectory="ngpc"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/SNK - Neo Geo Pocket Color.zip"
	fi

	if echo "$folder" | grep "^gamegear$" | read; then
		ConsoleId=15
		ConsoleName="Game Gear"
		ConsoleDirectory="gamegear"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Sega - Game Gear.zip"
	fi

	if echo "$folder" | grep "^atarijaguar$" | read; then
		ConsoleId=17
		ConsoleName="Atari Jaguar"
		ConsoleDirectory="atarijaguar"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Atari - Jaguar.zip"
	fi

	if echo "$folder" | grep "^nds" | read; then
		ConsoleId=18
		ConsoleName="Nintendo DS"
		ConsoleDirectory="nds"
		if [ ! -f /config/logs/downloaded/$folder ]; then
			ArchiveUrl="$(curl -s "https://archive.org/download/noIntroNintendoDsDecrypted2020Jan20" | grep ".zip" | grep -io '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//i' -e 's/["'"'"']$//i' | sed 's/\///g' | sort -u | sed 's|^|https://archive.org/download/noIntroNintendoDsDecrypted2020Jan20/|')"
		fi
	fi

	if echo "$folder" | grep "^pokemini" | read; then
		ConsoleId=24
		ConsoleName="Pokemon Mini"
		ConsoleDirectory="pokemini"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Nintendo - Pokemon Mini.zip"
	fi

	if echo "$folder" | grep "^atari2600$" | read; then
		ConsoleId=25
		ConsoleName="Atari 2600"
		ConsoleDirectory="atari2600"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Atari - 2600.zip"
	fi

	if echo "$folder" | grep "^atari5200$" | read; then
		ConsoleId=50
		ConsoleName="Atari 5200"
		ConsoleDirectory="atari5200"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Atari%20-%205200.zip"
	fi

	if echo "$folder" | grep "^arcade$" | read; then
		ConsoleId=27
		ConsoleName="Arcade"
		ConsoleDirectory="arcade"
		ArchiveUrl="https://archive.org/download/2020_01_06_fbn/roms/arcade.zip"
		SkipUnpackForHash="true"
	fi

	if echo "$folder" | grep "^virtualboy$" | read; then
		ConsoleId=28
		ConsoleName="VirtualBoy"
		ConsoleDirectory="virtualboy"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Nintendo - Virtual Boy.zip"

	fi

	if echo "$folder" | grep "^sg-1000$" | read; then
		ConsoleId=33
		ConsoleName="SG-1000"
		ConsoleDirectory="sg-1000"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Sega - SG-1000.zip"
	fi

	if echo "$folder" | grep "^coleco$" | read; then
		ConsoleId=44
		ConsoleName="ColecoVision"
		ConsoleDirectory="coleco"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Coleco - ColecoVision.zip"
	fi

	if echo "$folder" | grep "^atari7800$" | read; then
		ConsoleId=51
		ConsoleName="Atari 7800"
		ConsoleDirectory="atari7800"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Atari - 7800.zip"
	fi

	if echo "$folder" | grep "^wonderswan$" | read; then
		ConsoleId=53
		ConsoleName="WonderSwan"
		ConsoleDirectory="wonderswan"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Bandai - WonderSwan.zip"
	fi
	
	
	if echo "$folder" | grep "^wonderswancolor$" | read; then
		ConsoleId=53
		ConsoleName="WonderSwan"
		ConsoleDirectory="wonderswancolor"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Bandai - WonderSwan Color.zip"
	fi

	if echo "$folder" | grep "^intellivision$" | read; then
		ConsoleId=45
		ConsoleName="Intellivision"
		ConsoleDirectory="intellivision"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Mattel - Intellivision.zip"
	fi

	if echo "$folder" | grep "^vectrex$" | read; then
		ConsoleId=46
		ConsoleName="Vectrex"
		ConsoleDirectory="vectrex"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/GCE - Vectrex.zip"
	fi

	if echo "$folder" | grep "^apple2$" | read; then
		ConsoleId=38
		ConsoleName="Apple II"
		ConsoleDirectory="apple2"
	fi

	if echo "$folder" | grep "^saturn$" | read; then
		ConsoleId=39
		ConsoleName="Sega Saturn"
		ConsoleDirectory="saturn"
	fi

	if echo "$folder" | grep "^dreamcast$" | read; then
		ConsoleId=40
		ConsoleName="Sega Dreamcast"
		ConsoleDirectory="dreamcast"
	fi

	if echo "$folder" | grep "^psp$" | read; then
		ConsoleId=41
		ConsoleName="PlayStation Portable"
		ConsoleDirectory="psp"
	fi

	if echo "$folder" | grep "^msx$" | read; then
		ConsoleId=29
		ConsoleName="MSX"
		ConsoleDirectory="msx"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Microsoft - MSX.zip"
	fi

	if echo "$folder" | grep "^odyssey2$" | read; then
		ConsoleId=23
		ConsoleName="Magnavox Odyssey 2"
		ConsoleDirectory="odyssey2"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Magnavox - Odyssey2.zip"
	fi

	if echo "$folder" | grep "^ngp$" | read; then
		ConsoleId=14
		ConsoleName="SNK Neo Geo Pocket"
		ConsoleDirectory="ngp"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/SNK - Neo Geo Pocket.zip"
	fi	
	
	if echo "$folder" | grep "^tg16$" | read; then
		ConsoleId=8
		ConsoleName="NEC TurboGrafx-16"
		ConsoleDirectory="tg16"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/NEC - PC Engine - TurboGrafx 16.zip"
	fi
	
	if echo "$folder" | grep "^x68000$" | read; then
		ConsoleId=52
		ConsoleName="Sharp X68000"
		ConsoleDirectory="x68000"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Sharp%20-%20X68000.zip"
	fi

	if echo "$folder" | grep "^zxspectrum$" | read; then
		ConsoleId=59
		ConsoleName="ZX Spectrum"
		ConsoleDirectory="zxspectrum"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Sinclair%20-%20ZX%20Spectrum.zip"
	fi

	if echo "$folder" | grep "^c64$" | read; then
		ConsoleId=30
		ConsoleName="Commodore 64"
		ConsoleDirectory="c64"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Commodore%20-%2064.zip"
	fi

	if echo "$folder" | grep "^amiga$" | read; then
		ConsoleId=35
		ConsoleName="Amiga"
		ConsoleDirectory="amiga"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Commodore%20-%20Amiga.zip"
	fi
	
	if echo "$folder" | grep "^atarist$" | read; then
		ConsoleId=36
		ConsoleName="Atari ST"
		ConsoleDirectory="atarist"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Atari%20-%20ST.zip"
	fi

	if echo "$folder" | grep "^msx2$" | read; then
		ConsoleId=29
		ConsoleName="MSX2"
		ConsoleDirectory="msx2"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Microsoft%20-%20MSX2.zip"
	fi

	if echo "$folder" | grep "^channelf$" | read; then
		ConsoleId=57
		ConsoleName="Fairchild Channel F"
		ConsoleDirectory="channelf"
		ArchiveUrl="https://archive.org/download/hearto-1g1r-collection/hearto_1g1r_collection/Fairchild%20-%20Channel%20F.zip"
	fi

	if echo "$folder" | grep "^neogeocd$" | read; then
		ConsoleId=56
		ConsoleName="Neo Geo CD"
		ConsoleDirectory="neogeocd"
		ArchiveUrl="https://archive.org/download/perfectromcollection/NEOGEO.rar"
	fi
	
	if [ "$AquireRomSets" = "true" ]; then
		echo "$ConsoleName :: Getting ROMs"
		if [ ! -z "$ArchiveUrl" ]; then
			if [ -f /config/logs/downloaded/$folder ]; then
				echo "$ConsoleName :: ROMs previously downloaded :: Skipping..."
			else
				
				echo "$ConsoleName :: Downloading ROMs :: Please wait..."

				case "$ArchiveUrl" in
					*.zip|*.ZIP)
						DownloadOutput="/input/$folder/temp/rom.zip"
						Type=zip
						;;
					*.rar|*.RAR)
						DownloadOutput="/input/$folder/temp/rom.rar"
						Type=rar
						;;
				esac
				DlCount="$(echo "$ArchiveUrl" | wc -l)"
				OLDIFS="$IFS"
				IFS=$'\n'
				ArchiveUrls=($(echo "$ArchiveUrl"))
				IFS="$OLDIFS"
				for Url in ${!ArchiveUrls[@]}; do
					currentsubprocessid=$(( $Url + 1 ))
					
					DlUrl="${ArchiveUrls[$Url]}"
					echo "$ConsoleName :: Downloading URL :: $currentsubprocessid of $DlCount :: Downloading..."
				
					if [ -d /input/$folder/temp ]; then
						rm -rf /input/$folder/temp
					fi
					mkdir -p /input/$folder/temp
					axel -q -n $ConcurrentDownloadThreads --output="$DownloadOutput" "$DlUrl"
				
					if [ -f "$DownloadOutput" ]; then
						if [ "$Type" = "zip" ]; then
							DownloadVerification="$(unzip -t "$DownloadOutput" &>/dev/null; echo $?)"
						elif [ "$Type" = "rar" ]; then
							DownloadVerification="$(unrar t "$DownloadOutput" &>/dev/null; echo $?)"
						fi
						if [ "$DownloadVerification" = "0" ]; then
							echo "$ConsoleName :: Downloading URL :: $currentsubprocessid of $DlCount :: Download Complete!"
							echo "$ConsoleName :: Downloading URL :: $currentsubprocessid of $DlCount :: Unpacking to /input/$folder"
							if [ "$Type" = "zip" ]; then
								unzip -o -d "/input/$folder" "$DownloadOutput" >/dev/null
							elif [ "$Type" = "rar" ]; then
								unrar x "$DownloadOutput" "/input/$folder" &>/dev/null
							fi
							echo "$ConsoleName :: Downloading URL :: $currentsubprocessid of $DlCount :: Done!"
							if [ ! -d /config/logs/downloaded ]; then
								mkdir -p /config/logs/downloaded
								chown abc:abc /config/logs/downloaded
							fi
							if [ ! -f /config/logs/downloaded/$folder ]; then
								touch /config/logs/downloaded/$folder
								chown abc:abc /config/logs/downloaded/$folder
							fi
							if [ -d /input/$folder/temp ]; then
								rm -rf /input/$folder/temp
							fi
						else
							echo "$ConsoleName :: Downloading URL :: $currentsubprocessid of $DlCount :: Download Failed!"
							if [ -d /input/$folder/temp ]; then
								rm -rf /input/$folder/temp
							fi
							continue
						fi
					else
						echo "$ConsoleName :: Downloading URL :: $currentsubprocessid of $DlCount :: Download Failed!"
						if [ -d /input/$folder/temp ]; then
							rm -rf /input/$folder/temp
						fi
						continue
					fi
				done
			fi
		else
			echo "$ConsoleName :: ERROR :: No Archive.org URL found :: Skipping..."
		fi
	fi	

	if find /input/$folder -type f | read; then
		echo "$ConsoleName :: Checking For ROMS in /input/$folder :: ROMs found, processing..."
	else
		echo "$ConsoleName :: Checking For ROMS in /input/$folder :: No ROMs found, skipping..."
		continue
	fi

	# create hash library folder
	if [ ! -d /config/ra_hash_libraries ]; then
		mkdir -p /config/ra_hash_libraries
	fi	
	
	# delete existing console hash library
	if [ -f "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json" ]; then
		rm "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json"
	fi
	
	# aquire console hash library
	if [ ! -f "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json" ]; then
		echo "$ConsoleName :: Getting the console hash library from RetroAchievements.org..."
		curl -s "https://retroachievements.org/dorequest.php?r=hashlibrary&c=$ConsoleId" | jq '.' > "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json"
	fi

	SkipRahasher=false
	if cat "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json" | grep -i '"MD5List": \[\]' | read; then
		echo "$ConsoleName :: Unsupported RA platform detected"
		if [ "$EnableUnsupportedPlatforms" = "false" ]; then
			echo "$ConsoleName :: Enable Unsupported RA platforms disalbed :: Skipping... "
			continue
		else
			echo "$ConsoleName :: Begin Processing Unsupported RA platform..."
			SkipRahasher=true
		fi
	fi

	Process_Roms USA
	Process_Roms Europe
	Process_Roms World
	Process_Roms Japan
	Process_Roms Other
	
	# remove empty directories
	find /input/$folder -mindepth 1 -type d -empty -exec rm -rf {} \; &>/dev/null
	
	if [ "$ScrapeMetadata" = "true" ]; then
		if Skyscraper | grep -w "$folder" | read; then
			echo "$ConsoleName :: Begin Skyscraper Process..."
			if find /output/$folder -type f | read; then
				echo "$ConsoleName :: Checking For ROMS in /ouput/$folder :: ROMs found, processing..."
			else
				echo "$ConsoleName :: Checking For ROMS in /output/$folder :: No ROMs found, skipping..."
				continue
			fi
			# Scrape from screenscraper
			if [ "$SkipUnpackForHash" = "false" ]; then
				Skyscraper -f emulationstation -u $ScreenscraperUsername:$ScreenscraperPassword -p $folder -d /cache/$folder -s screenscraper -i /output/$folder --flags relative,videos,unattend,nobrackets,unpack
			else
				Skyscraper -f emulationstation -u $ScreenscraperUsername:$ScreenscraperPassword -p $folder -d /cache/$folder -s screenscraper -i /output/$folder --flags relative,videos,unattend,nobrackets
			fi
			# Save scraped data to output folder
			Skyscraper -f emulationstation -p $folder -d /cache/$folder -i /output/$folder --flags relative,videos,unattend,nobrackets
			# Remove skipped roms
			if [ -f /root/.skyscraper/skipped-$folder-cache.txt ]; then
				cat /root/.skyscraper/skipped-$folder-cache.txt | while read LINE;
				do 
					rm "$LINE"
				done
			fi
		else 
			echo "$ConsoleName :: Metadata Scraping :: ERROR :: Platform not supported, skipping..."
		fi 
	else
		echo "$ConsoleName :: Metadata Scraping disabled..."
		echo "$ConsoleName :: Enable by setting \"ScrapeMetadata=true\""
	fi
	
	# set permissions
	find /output/$folder -type d -exec chmod 777 {} \;
	find /output/$folder -type d -exec chown abc:abc {} \;
	find /output/$folder -type f -exec chmod 666 {} \;
	find /output/$folder -type f -exec chown abc:abc {} \;
	find /backup/$folder -type d -exec chmod 777 {} \;
	find /backup/$folder -type d -exec chown abc:abc {} \;
	find /backup/$folder -type f -exec chmod 666 {} \;
	find /backup/$folder -type f -exec chown abc:abc {} \;
done
exit $?
