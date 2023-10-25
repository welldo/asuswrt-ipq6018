#!/bin/sh

UI_TYPE=ASUSWRT

get_model(){
	local ODMPID=$(nvram get odmpid)
	local PRODUCTID=$(nvram get productid)
	if [ -n "${ODMPID}" ];then
		MODEL="${ODMPID}"
	else
		MODEL="${PRODUCTID}"
	fi
	echo_date "当前机型：$MODEL"
}

get_fw_type() {
	local KS_TAG=$(nvram get extendno|grep koolshare)
	if [ -d "/koolshare" ];then
		if [ -n "${KS_TAG}" ];then
			FW_TYPE_CODE="2"
			FW_TYPE_NAME="koolshare官改固件"
		else
			FW_TYPE_CODE="4"
			FW_TYPE_NAME="koolshare梅林改版固件"
		fi
	else
		if [ "$(uname -o|grep Merlin)" ];then
			FW_TYPE_CODE="3"
			FW_TYPE_NAME="梅林原版固件"
		else
			FW_TYPE_CODE="1"
			FW_TYPE_NAME="华硕官方固件"
		fi
	fi
	echo_date "当前固件：$FW_TYPE_NAME"
}	

get_ui_type(){
	# 获取机型
	get_model

	# 获取固件类型
	get_fw_type

	# 参数获取
	[ "${MODEL}" == "RT-AC86U" ] && local ROG_RTAC86U=0
	[ "${MODEL}" == "GT-AC2900" ] && local ROG_GTAC2900=1
	[ "${MODEL}" == "GT-AC5300" ] && local ROG_GTAC5300=1
	[ "${MODEL}" == "GT-AX11000" ] && local ROG_GTAX11000=1
	[ "${MODEL}" == "GT-AXE11000" ] && local ROG_GTAXE11000=1
	[ "${MODEL}" == "GT-AX6000" ] && local ROG_GTAX6000=1
	local KS_TAG=$(nvram get extendno|grep koolshare)
	local EXT_NU=$(nvram get extendno)
	local EXT_NU=$(echo ${EXT_NU%_*} | grep -Eo "^[0-9]{1,10}$")
	local BUILDNO=$(nvram get buildno)
	[ -z "${EXT_NU}" ] && EXT_NU="0"
	# RT-AC86U
	if [ -n "${KS_TAG}" -a "${MODEL}" == "RT-AC86U" -a "${EXT_NU}" -lt "81918" -a "${BUILDNO}" != "386" ];then
		# RT-AC86U的官改固件，在384_81918之前的固件都是ROG皮肤，384_81918及其以后的固件（包括386）为ASUSWRT皮肤
		ROG_RTAC86U=1
	fi
	# GT-AC2900
	if [ "${MODEL}" == "GT-AC2900" ] && [ "${FW_TYPE_CODE}" == "3" -o "${FW_TYPE_CODE}" == "4" ];then
		# GT-AC2900从386.1开始已经支持梅林固件，其UI是ASUSWRT
		ROG_GTAC2900=0
	fi
	# GT-AX11000
	if [ "${MODEL}" == "GT-AX11000" -o "${MODEL}" == "GT-AX11000_BO4" ] && [ "${FW_TYPE_CODE}" == "3" -o "${FW_TYPE_CODE}" == "4" ];then
		# GT-AX11000从386.2开始已经支持梅林固件，其UI是ASUSWRT
		ROG_GTAX11000=0
	fi
	# GT-AXE11000
	if [ "${MODEL}" == "GT-AXE11000" ] && [ "${FW_TYPE_CODE}" == "3" -o "${FW_TYPE_CODE}" == "4" ];then
		# GT-AXE11000从386.5开始已经支持梅林固件，其UI是ASUSWRT
		ROG_GTAXE11000=0
	fi
	# ROG UI
	if [ "${ROG_GTAC5300}" == "1" -o "${ROG_RTAC86U}" == "1" -o "${ROG_GTAC2900}" == "1" -o "${ROG_GTAX11000}" == "1" -o "${ROG_GTAXE11000}" == "1" -o "${ROG_GTAX6000}" == "1" ];then
		# GT-AC5300、RT-AC86U部分版本、GT-AC2900部分版本、GT-AX11000部分版本、GT-AXE11000官改版本， GT-AX6000 骚红皮肤
		UI_TYPE="ROG"
	fi
	# TUF UI
	if [ "${MODEL%-*}" == "TUF" ];then
		# 官改固件，橙色皮肤
		UI_TYPE="TUF"
	fi
}

# detect basic_center in jffs and remove it
if [ -d "/jffs/.basic_center" ];then
	rm -rf /jffs/.basic_center
	[ -d "/jffs/db" ] && rm -rf /jffs/db
	[ -d "/jffs/asdb" ] && rm -rf /jffs/asdb
	[ -L "/jffs/etc/profile" ] && rm -rf /jffs/etc
	[ -L "/jffs/configs/profile.add" ] && rm -rf /jffs/configs
	sync
fi

# http web should work under port 80
if [ "$(nvram get http_lanport)" != "80" -o -n "$(ps|grep -w httpd|grep -v grep|grep 81)" ];then
	nvram set http_lanport=80
	nvram commit
	service restart_httpd >/dev/null 2>&1
fi

# remove files after router started, incase dnsmasq won't start
[ -d "/jffs/configs/dnsmasq.d" ] && rm -rf /jffs/configs/dnsmasq.d/*

# make some folders
mkdir -p /jffs/scripts
mkdir -p /jffs/configs/dnsmasq.d
mkdir -p /jffs/etc
mkdir -p /tmp/upload

# install all
CENTER_TYPE=$(cat /jffs/.koolshare/webs/Module_Softcenter.asp 2>/dev/null| grep -Eo "/softcenter/app.json.js")
if [ -f "/koolshare/.soft_ver" ];then
	if [ -n "${CENTER_TYPE}" ];then
		# softceter in use
		CUR_VERSION=$(cat /koolshare/.soft_ver)
		ROM_VERSION=$(cat /rom/etc/koolshare/.soft_ver_old)
	else
		# koolcenter in use
		CUR_VERSION=$(cat /koolshare/.soft_ver)
		ROM_VERSION=$(cat /rom/etc/koolshare/.soft_ver)
	fi
else
	CUR_VERSION="0"
	ROM_VERSION=$(cat /rom/etc/koolshare/.soft_ver)
fi
COMP=$(/rom/etc/koolshare/bin/versioncmp $CUR_VERSION $ROM_VERSION)

if [ ! -d "/jffs/.koolshare" -o "$COMP" == "1" ]; then
	# remove before install
	rm -rf /koolshare/res/soft-v19 >/dev/null 2>&1
	rm -rf /koolshare/.soft_ver >/dev/null 2>&1
	rm -rf /koolshare/.soft_ver_new >/dev/null 2>&1
	rm -rf /koolshare/.soft_ver_old >/dev/null 2>&1
	
	# start to install, use koolcenter any way
	mkdir -p /jffs/.koolshare
	cp -rf /rom/etc/koolshare/* /jffs/.koolshare/
	cp -rf /rom/etc/koolshare/.soft_ver* /jffs/.koolshare/

	# different model need different skin
	get_ui_type
	if [ "${UI_TYPE}" == "ROG" ];then
		cp /jffs/.koolshare/res/softcenter_rog.css /jffs/.koolshare/res/softcenter.css >/dev/null 2>&1
	elif [ "${UI_TYPE}" == "TUF" ];then
		sed -i 's/3e030d/3e2902/g;s/91071f/92650F/g;s/680516/D0982C/g;s/cf0a2c/c58813/g;s/700618/74500b/g;s/530412/92650F/g' /jffs/.koolshare/res/softcenter_rog.css
		cp /jffs/.koolshare/res/softcenter_rog.css /jffs/.koolshare/res/softcenter.css >/dev/null 2>&1
	fi
	rm -rf /jffs/.koolshare/res/softcenter_rog.css >/dev/null 2>&1

	# premissions
	mkdir -p /jffs/.koolshare/configs/
	chmod 755 /koolshare/bin/*
	chmod 755 /koolshare/init.d/*
	chmod 755 /koolshare/perp/*
	chmod 755 /koolshare/perp/.boot/*
	chmod 755 /koolshare/perp/.control/*
	chmod 755 /koolshare/perp/httpdb/*
	chmod 755 /koolshare/scripts/*

	# ssh PATH environment
	rm -rf /jffs/configs/profile.add >/dev/null 2>&1
	rm -rf /jffs/etc/profile >/dev/null 2>&1
	source_file=$(cat /etc/profile|grep -v nvram|awk '{print $NF}'|grep -E "profile"|grep "jffs"|grep "/")
	source_path=$(dirname /jffs/etc/profile)
	if [ -n "${source_file}" -a -n "${source_path}" ];then
		rm -rf ${source_file} >/dev/null 2>&1
		mkdir -p ${source_path}
		ln -sf /koolshare/scripts/base.sh ${source_file} >/dev/null 2>&1
	fi

	# make some link
	[ ! -L "/koolshare/bin/base64_decode" ] && ln -sf /koolshare/bin/base64_encode /koolshare/bin/base64_decode
	[ ! -L "/koolshare/scripts/ks_app_remove.sh" ] && ln -sf /koolshare/scripts/ks_app_install.sh /koolshare/scripts/ks_app_remove.sh
	[ ! -L "/jffs/.asusrouter" ] && ln -sf /koolshare/bin/kscore.sh /jffs/.asusrouter
	sync
fi

# check start up scripts 
if [ ! -f "/jffs/scripts/wan-start" ];then
	cat > /jffs/scripts/wan-start <<-EOF
	#!/bin/sh
	/koolshare/bin/ks-wan-start.sh start
	EOF
else
	STARTCOMAND1=$(cat /jffs/scripts/wan-start | grep -c "/koolshare/bin/ks-wan-start.sh start")
	[ "$STARTCOMAND1" -gt "1" ] && sed -i '/ks-wan-start.sh/d' /jffs/scripts/wan-start && sed -i '1a /koolshare/bin/ks-wan-start.sh start' /jffs/scripts/wan-start
	[ "$STARTCOMAND1" == "0" ] && sed -i '1a /koolshare/bin/ks-wan-start.sh start' /jffs/scripts/wan-start
fi

if [ ! -f "/jffs/scripts/nat-start" ];then
	cat > /jffs/scripts/nat-start <<-EOF
	#!/bin/sh
	/koolshare/bin/ks-nat-start.sh start_nat
	EOF
else
	STARTCOMAND2=$(cat /jffs/scripts/nat-start | grep -c "/koolshare/bin/ks-nat-start.sh start_nat")
	[ "$STARTCOMAND2" -gt "1" ] && sed -i '/ks-nat-start.sh/d' /jffs/scripts/nat-start && sed -i '1a /koolshare/bin/ks-nat-start.sh start_nat' /jffs/scripts/nat-start
	[ "$STARTCOMAND2" == "0" ] && sed -i '1a /koolshare/bin/ks-nat-start.sh start_nat' /jffs/scripts/nat-start
fi

if [ ! -f "/jffs/scripts/post-mount" ];then
	cat > /jffs/scripts/post-mount <<-EOF
	#!/bin/sh
	/koolshare/bin/ks-mount-start.sh start \$1
	EOF
else
	STARTCOMAND3=$(cat /jffs/scripts/post-mount | grep -c "/koolshare/bin/ks-mount-start.sh start \$1")
	[ "$STARTCOMAND3" -gt "1" ] && sed -i '/ks-mount-start.sh/d' /jffs/scripts/post-mount && sed -i '1a /koolshare/bin/ks-mount-start.sh start $1' /jffs/scripts/post-mount
	[ "$STARTCOMAND3" == "0" ] && sed -i '/ks-mount-start.sh/d' /jffs/scripts/post-mount && sed -i '1a /koolshare/bin/ks-mount-start.sh start $1' /jffs/scripts/post-mount
fi

if [ ! -f "/jffs/scripts/services-start" ];then
	cat > /jffs/scripts/services-start <<-EOF
	#!/bin/sh
	/koolshare/bin/ks-services-start.sh
	EOF
else
	STARTCOMAND4=$(cat /jffs/scripts/services-start | grep -c "/koolshare/bin/ks-services-start.sh")
	[ "$STARTCOMAND4" -gt "1" ] && sed -i '/ks-services-start.sh/d' /jffs/scripts/services-start && sed -i '1a /koolshare/bin/ks-services-start.sh' /jffs/scripts/services-start
	[ "$STARTCOMAND4" == "0" ] && sed -i '1a /koolshare/bin/ks-services-start.sh' /jffs/scripts/services-start
fi

if [ ! -f "/jffs/scripts/services-stop" ];then
	cat > /jffs/scripts/services-stop <<-EOF
	#!/bin/sh
	/koolshare/bin/ks-services-stop.sh
	EOF
else
	STARTCOMAND5=$(cat /jffs/scripts/services-stop | grep -c "/koolshare/bin/ks-services-stop.sh")
	[ "$STARTCOMAND5" -gt "1" ] && sed -i '/ks-services-stop.sh/d' /jffs/scripts/services-stop && sed -i '1a /koolshare/bin/ks-services-stop.sh' /jffs/scripts/services-stop
	[ "$STARTCOMAND5" == "0" ] && sed -i '1a /koolshare/bin/ks-services-stop.sh' /jffs/scripts/services-stop
fi

if [ ! -f "/jffs/scripts/unmount" ];then
	cat > /jffs/scripts/unmount <<-EOF
	#!/bin/sh
	/koolshare/bin/ks-unmount.sh \$1
	EOF
else
	STARTCOMAND6=$(cat /jffs/scripts/unmount | grep -c "/koolshare/bin/ks-unmount.sh \$1")
	[ "$STARTCOMAND6" -gt "1" ] && sed -i '/ks-unmount.sh/d' /jffs/scripts/unmount && sed -i '1a /koolshare/bin/ks-unmount.sh $1' /jffs/scripts/unmount
	[ "$STARTCOMAND6" == "0" ] && sed -i '1a /koolshare/bin/ks-unmount.sh $1' /jffs/scripts/unmount
fi
chmod +x /jffs/scripts/*
sync
