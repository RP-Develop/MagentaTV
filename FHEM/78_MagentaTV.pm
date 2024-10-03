# $Id: 78_MagentaTV.pm 221625 2023-08-06 00:00:00Z RalfP $
###############################################################################
#
#     78_MagentaTV.pm 
#
#     An FHEM Perl module for controlling of Telekom MagentaTV Receivers
#
#
#	  Copyright by Ralf Putzke
#	  e-mail: ralf.putzke@RP-Dev.de
#
#	  Based on
#     - SONOS (Reinerlein)
#	  - 98_DLNARenderer.pm (dominik)
#     - MagentaTV Binding of openHAB (markus7017)
#       https://github.com/markus7017/org.openhab.binding.magentatv/blob/master/README.md
#
#     many thanks for this pre work 
#     and thanks to all Fhem developers, who have worked with UPnP 
#
#
#
###############################################################################

package main;
use strict;
use warnings;

# Laden evtl. abhängiger Perl- bzw. FHEM-Hilfsmodule
use HttpUtils; 		# https://wiki.fhem.de/wiki/HttpUtils
use JSON;
use Digest::MD5  qw(md5 md5_hex md5_base64);
use Blocking;
use HTML::Entities;
use Data::Dumper;
use Date::Parse; 
use Encode qw(encode decode);
#use FHEM::Meta;

# UPnP::ControlPoint laden
my $gPath = '';
BEGIN {
	$gPath = substr($0, 0, rindex($0, '/'));
}
if (lc(substr($0, -7)) eq 'fhem.pl') {
	$gPath = $attr{global}{modpath}.'/FHEM';
}
use lib ($gPath.'/lib', $gPath.'/FHEM/lib', './FHEM/lib', './lib', './FHEM', './', '/usr/local/FHEM/share/fhem/FHEM/lib');

use UPnP::ControlPoint;


# Modul Constanten #############################################################

use constant VERSION 			=> "v1.1.7";

use constant HOST_LOGIN			=> "https://appepmfk10002.prod.sngtv.t-online.de:33227";
#use constant HOST_ACCOUNT		=> "https://accounts.login.idm.telekom.com";
#use constant HOST_API			=> "https://api.prod.sngtv.magentatv.de";
#use constant HOST				=> "https://web.magentatv.de";
#use constant USER_AGENT 		=> "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Safari/605.1.15";
#use constant USER_AGENT 		=> "Darwin/18.7.0 UPnP/1.0 HUAWEI_iCOS/iCOS V1R1C00 DLNADOC/1.50";
use constant USER_AGENT 		=> "Mozilla/5.0";
#use constant BROWSER			=> "Mac_safari_13";
use constant BROWSER			=> "Iphone";
use constant CLIENT_ID 			=> "10LIVESAM30000004901NGTVACIOS00000000000";
								  #"10LIVESAM30000004901NGTVMAGENTA000000000"
								  #"10LIVESAM30000004901NGTVWEB0000000000000"
use constant TERMINAL_VENDOR	=> "Fhem";


# Definitions ##################################################################

my %Login = (
				"userId"	=> "Guest",
				"mac"		=> "00:00:00:00:00:00"
			);
			
my %Authenticate = 	(
						"terminalid" 		=> "00:00:00:00:00:00",
						"mac" 				=> "00:00:00:00:00:00",
						"terminaltype" 		=> "Iphone",    	#"MACWEBTV",
						"utcEnable" 		=> "1",
						"timezone" 			=> "Africa/Ceuta",
						"userType" 			=> "3",
						"terminalvendor" 	=> TERMINAL_VENDOR,	
						"preSharedKeyID" 	=> "NGTV000001",   	#"PC01P00002",
						"cnonce" 			=> ""	
					);

my @terminalDetail =	(
							{
								"key"	=> "HardwareSupplier",
								"value"	=> "Fhem"
							},
							{
								"key"	=> "DeviceClass",
								"value"	=> "IPhone" #PC
							},
							{
								"key"	=> "DeviceStorage",
								"value"	=> "1"
							},
							{
								"key"	=> "DeviceStorageSize",
								"value"	=> "12475"
							},
							{	"key"	=> "GUID",
								"value"	=> ""
							}
						);
						
my @caDeviceInfo =		(
							{
								"caDeviceType"	=> "6",
								"caDeviceId"	=> ""
							}
						);

my %DTAuthenticate = 	(	
							"userType"			=> "1",
							"terminalid"		=> "",
							"mac"				=> "",
							"terminaltype" 		=> "Iphone",  		#"MACWEBTV",
							"utcEnable" 		=> "1",
							"timezone" 			=> "Africa/Ceuta",
							"terminalDetail" 	=> \@terminalDetail,
							"softwareVersion"	=> "",
							"osversion"			=> "",
							"terminalvendor" 	=> TERMINAL_VENDOR,   
							"caDeviceInfo"		=> \@caDeviceInfo,
							"accessToken" 		=> "",
							"preSharedKeyID" 	=> "NGTV000001",   	#"PC01P00002",
							"cnonce" 			=> ""
						);

my %HeartBit = 			(
							"userid" => ""
						);

my %ReplaceDevice = 	(
							"orgDeviceId"	=> "",					#welche deviceId soll rausgeschmissen werden
							"destDeviceId"	=> "00:00:00:00:00:00",
							"userid"		=> ""
						);
						
my %Logout = 			(
							"type" => "1"
						);
						
my %SubmitDeviceInfo =	(
							"deviceType" 		=> "IMP",
							"deviceToken" 		=> "",
							"tokenExpireTime" 	=> ""
						);
						
my %DeviceList = 		(
							"userid" 		=> "",
							"deviceType" 	=> "0;2;17",
							"filterUnbound" => "1"
						);  						

my %ChannelInfo = 		(
          					"metaDataVer" => "Channel/1.1",
							"filterlist" => [
												{
												  "key" => "IsHide",
												  "value" => "-1"
												}
											  ],
							 "properties" => [
												{
												  "name" => "logicalChannel",
												  "include" => "/channellist/logicalChannel/contentId,/channellist/logicalChannel/name,/channellist/logicalChannel/chanNo,/channellist/logicalChannel/pictures/picture/imageType,/channellist/logicalChannel/pictures/picture/href,/channellist/logicalChannel/sysChanNo,/channellist/logicalChannel/physicalChannels/physicalChannel/mediaId,/channellist/logicalChannel/physicalChannels/physicalChannel/definition"
												}
											  ],
							"channelNamespace" => "4",
							"returnSatChannel" => "0"
        				);

my %CustomChanNo = 		(
          					"channelNamespace" 	=> "",
          					"deviceId" 			=> "",
          					"queryType" 		=> "0"
						);
						
my %favorite =			(
							"filterlist" 	=> [
													{
														"key" 	=> "IsHide",
														"value" => "-1"
													}
												]
						);
						
my %PlayBillContextEx = (
							"date" 			=> "",
							"type" 			=> "2",
							"preNumber" 	=> "0",
							"nextNumber" 	=> "1", 	#Anzahl der nächsten Sendungen
							"channelid" 	=> ""
						);
						
my %error = (
				"DeviceList" 	=> 	{
									"83886081" 	=> 	{
														"t" => "Aktion nicht möglich",
														"s" => "QueryPVR failed, error code:xxx",
														"m" => "Bitte versuchen Sie es später erneut."
													},
									"85983514" 	=> 	{
														"t" => "Aktion nicht möglich",
														"s" => "QueryPVR failed, error code:xxx",
														"m" => "Bitte versuchen Sie es später erneut."
													},
									"87097345" 	=> 	{
														"t" => "Aktion nicht möglich",
														"s" => "QueryPVR failed, error code:xxx",
														"m" => "Bitte versuchen Sie es später erneut."
													},
									"85983406" 	=> 	{
														"t" => "Login erforderlich",
														"s" => "QueryPVR failed, error code:xxx",
														"m" => "Um diese Aktion ausführen zu können, müssen Sie eingeloggt sein."
													},
									"default" 	=> 	{
														"t" => "Aktion nicht möglich",
														"s" => "Get device list failed, error code:xxx",
														"m" => "Es ist ein Fehler aufgetreten. Fehlercode: xxx. Bitte versuchen Sie es später erneut."
													},                             	
                                	},
				"Authenticate"	=> 	{
									"67174404" 	=> 	{
                										"t" => "Es ist ein Fehler aufgetreten",
                										"s" => "UserID or password is incorrect.",
                										"m" => "Login wiederholen Benutzername oder Passwort ist nicht korrekt."
            										},
									"33620481" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "UserID or password is incorrect.",
														"m" => "Login wiederholen Benutzername oder Passwort ist nicht korrekt."
													},
									"33620231" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "Your Account has been locked",
														"m" => "Login nicht möglich Ihr Konto wurde vorübergehend gesperrt. Bitte wenden Sie sich an unseren Kundenservice, um mehr zu erfahren."
													},
									"33620232" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "Your Account has been locked",
														"m" => "Login nicht möglich Ihr Konto wurde vorübergehend gesperrt. Bitte wenden Sie sich an unseren Kundenservice, um mehr zu erfahren."
													},
									"33619970" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "Your Account has been suspended.",
														"m" => "Login nicht möglich Ihr Konto wurde vorübergehend gesperrt. Bitte wenden Sie sich an unseren Kundenservice, um mehr zu erfahren."
													},
									"33619984" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "Equipment replacement",
														"m" => "Max. Anzahl an Geräten erreicht. Bitte löschen Sie nicht mehr benötigte Geräte."
													},
									"85983373" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "Your device is not allowed to login in your area.",
														"m" => "Login nicht möglich Es scheint ein Problem mit Ihrem Media Receiver zu geben. Bitte wenden Sie sich an unseren Kundenservice."
													},
									"85983545" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "The number of HLS OTT users to allow binding has reached its maximum.",
														"m" => "Max. Anzahl an Geräten erreicht. Bitte löschen Sie nicht mehr benötigte Geräte."
													},
									"default" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "Login failed",
														"m" => "Entschuldigung Der Login konnte nicht ausgeführt werden. Bitte versuchen Sie es erneut oder wenden Sie sich an unseren Kundenservice."
													},
 									},		
				"DTAuthenticate"	=> 	{
									"85983384" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich, da ein Fehler aufgetreten ist. Bitte versuchen Sie es später erneut."
													},
									"33619970" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich, da Ihr Konto vorübergehend gesperrt wurde. Bitte wenden Sie sich an den Kundenservice der Telekom: 0800 33 01000 (kostenlos)."
													},
									"33620481" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte starten Sie die App neu. Sollte es danach weiterhin Störungen geben, wenden Sie sich bitte an den Kundenservice der Telekom: 0800 33 01000 (kostenlos)."
													},
									"85983373" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte wenden Sie sich an den Kundenservice der Telekom: 0800 33 01000 (kostenlos)."
													},
									"85983377" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"33620231" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Ihr Konto wurde vorübergehend gesperrt. Bitte wenden Sie sich an den Kundenservice der Telekom: 0800 33 01000 (kostenlos)."
													},
									"33620232" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Ihr Konto wurde vorübergehend gesperrt. Bitte wenden Sie sich an den Kundenservice der Telekom: 0800 33 01000 (kostenlos)."
													},
									"117637376" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"33620483" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983240" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983265" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983303" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983375" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983378" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983391" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983392" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"87097345" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"87031811" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983570" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983588" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983560" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983561" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"33619984" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983545" 	=> 	{
														"t" => "Verbinden nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Sie haben bereits die max. Anzahl an Benutzern erreicht. (F20715)"
													},
									"117440517" 	=> 	{
														"t" => "Verbinden nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983374" 	=> 	{
														"t" => "Verbinden nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983414" 	=> 	{
														"t" => "Verbinden nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983445" 	=> 	{
														"t" => "Verbinden nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983454" 	=> 	{
														"t" => "Verbinden nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983497" 	=> 	{
														"t" => "Verbinden nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983502" 	=> 	{
														"t" => "Verbinden nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"85983503" 	=> 	{
														"t" => "Verbinden nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"33620737" 	=> 	{
														"t" => "Verbinden nicht möglich",
														"s" => "Your Device or operation system is forbidden to log in",
														"m" => "Login nicht möglich. Bitte versuchen Sie es später erneut."
													},
									"default" 	=> 	{
														"t" => "Login nicht möglich",
														"s" => "Authenticate in DT system failed, error code:xxx",
														"m" => "Login fehlgeschlagen. Bitte versuchen Sie es noch einmal."
													}, 									
 									},
 				"Response"		=> 	{
 									"-2" 		=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "Service is temporarily unavailable.",
														"m" => "Service momentan nicht verfügbar. Bitte versuchen Sie es später erneut."
													},
									"-3" 		=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "Service is temporarily unavailable.",
														"m" => "Service momentan nicht verfügbar. Bitte versuchen Sie es später erneut."
													},
									"85983520" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "The subscriber account is deleted.",
														"m" => "Login nicht möglich Ihr Konto wurde gelöscht. Bitte wenden Sie sich an unseren Kundenservice, um mehr zu erfahren."
													},
									"85983521" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "The subscriber account is suspended.",
														"m" => "Login nicht möglich Ihr Konto wurde vorübergehend gesperrt. Bitte wenden Sie sich an unseren Kundenservice, um mehr zu erfahren."
													},
									"85983522" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "Your device is deleted by the service provider.",
														"m" => "Gerät gelöscht Bitte wenden Sie sich an unseren Kundenservice, um mehr zu erfahren."
													},
									"85983523" 	=> 	{
														"t" => "Automatische Abmeldung",
														"s" => "Your device is unbinded by the service provider.",
														"m" => "Sie wurden automatisch abgemeldet, da sich ein anderer Benutzer angemeldet hat."
													},
									"85983527" 	=> 	{
														"t" => "Automatische Abmeldung",
														"s" => "Sesssion Time out, error code:xxx, you must login again.",
														"m" => "Sie wurden automatisch abgemeldet, da sich ein anderer Benutzer angemeldet hat."
													},
									"85983406" 	=> 	{
														"t" => "Automatische Abmeldung",
														"s" => "Your device is unbinded by the service provider.",
														"m" => "Sie wurden automatisch abgemeldet, da sich ein anderer Benutzer angemeldet hat."
													},
									"85983539" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "Your service has changed.",
														"m" => "Service wurde geändert Bitte versuchen Sie es erneut oder starten Sie das System neu."
													},
									"85983549" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "Your network address has changed.",
														"m" => "Geänderte Netzwerkadresse Bitte versuchen Sie es erneut oder starten Sie das System neu."
													},
									"default" 	=> 	{
														"t" => "Es ist ein Fehler aufgetreten",
														"s" => "Service is temporarily unavailable, error code: ",
														"m" => "Service momentan nicht verfügbar. Fehlercode: xxx. Bitte versuchen Sie es später erneut."
													},
									} 									
			);

# Transitions ##################################################################
                
# playBackState aus Event und PlayerState
# Bedeutung nicht gefunden
my %playBackState = ( 	
						0 => "STOP",
				 		1 => "RUN"
			   		);
# 0: NONE =>standby
# 1: RUN =>online

# running_status: The options are as follows:
# http://support.huawei.com/hedex/pages/DOC1100366313CEH0713H/01/DOC1100366313CEH0713H/01/resources/dsv_hdx_idp/DSV/en/en-us_topic_0094619523.html
my %runningStatus = ( 	
						0 => "NONE",
						1 => "STOP",
						2 => "START>",
						3 => "PAUSE",
						4 => "PLAY",
						5 => "SERVICE OFF AIR",
						6 => "NONE",
						7 => "NONE"
					);
# 0: undefined
# 1: not running
# 2: to start in a few seconds (for example: for video recording)
# 3: pausing
# 4: running
# 5: service off-air
# 6 and 7: reserved for future use


# newPlayMode event data
# http://support.huawei.com/hedex/pages/DOC1100366313CEH0713H/01/DOC1100366313CEH0713H/01/resources/dsv_hdx_idp/DSV/en/en-us_topic_0094619231.html
my %newPlayMode = ( 
					0 => "STOP",
				 	1 => "PAUSE",
				 	2 => "PLAY",
				 	3 => "<<PLAY>>",
				 	4 => "PLAY Multicast",
				 	5 => "PLAY Unicast",
				 	20 => "BUFFERING"
			   	);
# 0: STOP: stop status.
# 1: PAUSE: pause status.
# 2: NORMAL_PLAY: normal playback status for non-live content (including TSTV).
# 3: TRICK_MODE: trick play mode, such as fast-forward, rewind, slow-forward, and slow-rewind.
# 4: MULTICAST_CHANNEL_PLAY: live broadcast status of IPTV multicast channels and DVB channels.
# 5: UNICAST_CHANNEL_PLAY: live broadcast status of IPTV unicast channels and OTT channels.
# 20: BUFFERING: playback buffering status, including playing cPVR content during the recording, playing content during the download, playing the OTT content, and no data in the buffer area.

# Playback rate. If the playback mode is TRICK_MODE (the new_play_mode field is set to TRICK_MODE), the parameter is mandatory. The options are as follows:
# 64: fast-forwarding at the 64x speed (available only to certain sites)
# 32: fast-forwarding at the 32x speed
# 16: fast-forwarding at the 16x speed
# 8: fast-forwarding at the 8x speed
# 4: fast-forwarding at the 4x speed
# 2: fast-forwarding at the 2x speed
# 1: normal playback
# 0: paused
# -2: rewinding at the 2x speed
# -4: rewinding at the 4x speed
# -8: rewinding at the 8x speed
# -16: rewinding at the 16x speed
# -32: rewinding at the 32x speed
# -64: rewinding at the 64x speed (available only to certain sites)


# list of valid key codes see
# http://support.huawei.com/hedex/pages/DOC1100366313CEH0713H/01/DOC1100366313CEH0713H/01/resources/dsv_hdx_idp/DSV/en/en-us_topic_0094619112.html
# https://github.com/Xyaren/homeassistant-magentatv/blob/main/custom_components/magentatv/api/const.py
my %keyMap = (	
				"POWER" 	=> "0x0100",
    			"ON" 		=> "0x0480",
    			"OFF" 		=> "0x0481",			
       			"DELETE" 	=> "0x0008",
        		"BACK" 		=> "0x0008",
        		"OK" 		=> "0x000D",
        		"ENTER" 	=> "0x000D",
	       		"SPACE" 	=> "0x0020",
        		"PGUP" 		=> "0x0021",
        		"PGDOWN" 	=> "0x0022",
        		"UP" 		=> "0x0026",
        		"DOWN" 		=> "0x0028",
        		"LEFT" 		=> "0x0025",
        		"RIGHT" 	=> "0x0027",
        		"0" 		=> "0x0030",
        		"1" 		=> "0x0031",
        		"2" 		=> "0x0032",
        		"3" 		=> "0x0033",
        		"4" 		=> "0x0034",
        		"5" 		=> "0x0035",
        		"6" 		=> "0x0036",
        		"7" 		=> "0x0037",
        		"8" 		=> "0x0038",
        		"9" 		=> "0x0039",
         		"POUND" 	=> "0x0069",
        		"STAR" 		=> "0x006A",
       			"F1" 		=> "0x0070",
        		"F2" 		=> "0x0071",
       			"F3" 		=> "0x0072",
        		"F4" 		=> "0x0073",
       			"F5" 		=> "0x0074",
        		"F6" 		=> "0x0075",
       			"F7" 		=> "0x0076",
        		"F8" 		=> "0x0077",
       			"F9" 		=> "0x0078",
        		"F10" 		=> "0x0079",
       			"F11" 		=> "0x007A",
        		"F12" 		=> "0x007B",
       			"F13" 		=> "0x007C",
        		"F14" 		=> "0x007D",
       			"F15" 		=> "0x007E",
        		"F16" 		=> "0x007F",
         		"IPTV" 		=> "0x0081",
        		"PC" 		=> "0x0082",
       			"SOURCE" 	=> "0x0083",
        		"PIP" 		=> "0x0084",
        		"CHUP" 		=> "0x0101",
        		"CHDOWN" 	=> "0x0102",
        		"VOLUP" 	=> "0x0103",
        		"VOLDOWN" 	=> "0x0104",
        		"MUTE" 		=> "0x0105",
        		"TRACK" 	=> "0x0106",
        		"NEXTCH" 	=> "0x0107",
       			"PLAY" 		=> "0x0107",
        		"PAUSE" 	=> "0x0107",
         		"FORWARD" 	=> "0x0108",
        		"REWIND" 	=> "0x0109",
				"END" 		=> "0x010A",
				"SKIP_BACK" => "0x010A",
        		"PREVCH" 	=> "0x010B",
        		"INFO" 		=> "0x010C",
				"INTER" 	=> "0x010D",
        		"STOP" 		=> "0x010E",
        		"MENU" 		=> "0x0110",
         		"PORTAL" 	=> "0x0110",
        		"EPG" 		=> "0x0111",
        		"RED" 		=> "0x0113",
        		"GREEN" 	=> "0x0114",
        		"YELLOW" 	=> "0x0115",
        		"BLUE" 		=> "0x0116",
        		"SWITCH"	=> "0x0118",
        		"FAV" 		=> "0x0119",
				"HELP" 		=> "0x011C",
				"SETTINGS" 	=> "0x011D",
				"SUBTITLE" 	=> "0x0236",
         		"SEARCH" 	=> "0x0451",
         		"TVMENU" 	=> "0x0454",
         		"VODMENU" 	=> "0x0455",
         		"TVODMENU" 	=> "0x0456",
         		"NVODMENU" 	=> "0x0458",
         		"REPLAY" 	=> "0x045B",
         		"SKIP" 		=> "0x045C",
         		"EXIT" 		=> "0x045D",
         		"LASTCH" 	=> "0x045E",
         		"RECORDINGS"=> "0x045F",
        		"OPTION" 	=> "0x0460",
        		"RECORD" 	=> "0x0461",
        		"RADIO" 	=> "0x0462",
       			"DVB_TXT" 	=> "0x0560",
       			"TTEXT" 	=> "0x0560",
        		"MULTIVIEW" => "0x0562"
    		);

# FHEM Modulfunktionen #########################################################

sub MagentaTV_Initialize {
    my ($hash) = @_;

    $hash->{DefFn}      		= "MagentaTV_Define";
    $hash->{UndefFn}    		= "MagentaTV_Undef";
    $hash->{DeleteFn} 			= "MagentaTV_Delete";
    $hash->{SetFn}      		= "MagentaTV_Set";
    $hash->{GetFn}      		= "MagentaTV_Get";
    $hash->{AttrFn}     		= "MagentaTV_Attr";
    $hash->{ReadFn}     		= "MagentaTV_Read";
    #$hash->{ShutdownFn} 		= "MagentaTV_Shutdown";
    $hash->{DelayedShutdownFn} 	= "MagentaTV_DelayedShutdown";

  	# Attr sind den Geräten ACCOUNT RECEIVER über setDevAttrList zugeordnet 
  	$hash->{AttrList} =	"disable:1,0 expert:1,0 ";
  	$hash->{AttrList} .= $readingFnAttributes;
 	
  	$hash->{FW_detailFn} = "MagentaTV_detailFn";
  	$hash->{FW_addDetailToSummary} = 1;
 	$hash->{FW_deviceOverview} = 1;
    
    #return FHEM::Meta::InitMod( __FILE__, $hash );
}

sub MagentaTV_Define {
    my ($hash, $def) = @_;
    #return $@ unless ( FHEM::Meta::SetInternals($hash) );
    
    my @param = split('[ \t]+', $def);
    
   	$hash->{NAME}  = $param[0];
	my $name = $hash->{NAME};
	
    #use version 0.60; our $hash->{VERSION} = FHEM::Meta::Get( $hash, 'version' );
	$hash->{VERSION} = VERSION;
	
	Log3 $name, 5, $name.": <Define> Called for $name : ".join(" ",@param);
    
	if(IsDisabled($name) || !defined($name)) {
	    RemoveInternalTimer($hash);
	    $hash->{STATE} = "Disabled";
	    return undef;
	}
	
   	if(($param[2] eq "RECEIVER") && (int(@param) == 4)){
		$hash->{SUBTYPE} = "RECEIVER";
		$hash->{UDN} = $param[3];
		
		$modules{$hash->{TYPE}}->{FW_addDetailToSummary} = 1; #Roomdarstellung
		
		setDevAttrList($name, "disable:1,0 expert:1,0 detectPlayerState:1,0 getPlayerStateInterval SenderListType:custom,favorit Programinfo:1,0 PrograminfoReadings:0,1 PrograminfoNext:1,0 ControlButtons:1,0 renewSubscription ".$readingFnAttributes);

		readingsSingleUpdate($hash,"state","offline",1);
		readingsSingleUpdate($hash,"pairing","none",1);
		MagentaTV_TriggerDetailFn($hash);
		
		readingsSingleUpdate($hash,"lastRequestError","",1);
		
		MagentaTV_StartReceiver($hash);

   	}
   	elsif((($param[2] eq "ACCOUNT") && (int(@param) == 5)) || (int(@param) == 4)){  #ToDo evtl auf @ prüfen im Nutzernamen bei Prüfung auf ==4
		$hash->{SUBTYPE} = "ACCOUNT";

		$modules{$hash->{TYPE}}->{FW_addDetailToSummary} = 0;
		
		my $user = $param[@param-2];
		my $pass = $param[@param-1];
		my $username = MagentaTV_encrypt($user);
		my $password = MagentaTV_encrypt($pass);
		
		Log3 $name, 5, "$name: encrypt $user/$pass to $username/$password" if($user ne $username || $pass ne $password);

		$hash->{friendlyName} = "PAD:".AttrVal("global", "title", "Fhem");
		$hash->{DEF} = "ACCOUNT $username $password";
				
		#wenn kein room angegeben ist - trifft bei neuem define zu 
		CommandAttr(undef, $name." room MagentaTV") if ( AttrVal( $name, "room", "" ) eq "" );
		
		setDevAttrList($name, "disable:1,0 expert:1,0 ignoreUDNs acceptedUDNs ignoredIPs usedonlyIPs retryConnection:1,0 RescanNetworkInterval subscriptionPort searchPort reusePort:0,1 ".$readingFnAttributes);

		$hash->{helper}{username} = $username;
		$hash->{helper}{password} = $password;
		
		readingsSingleUpdate($hash,"lastRequestError","",1);
		
		if( $init_done ) {
			InternalTimer(gettimeofday()+3, "MagentaTV_StartAccount", $hash);
		}
		else{
			InternalTimer(gettimeofday()+10, "MagentaTV_StartAccount", $hash);  
		}
		#$hash->{STATE} = "wait of initializing";
		readingsSingleUpdate($hash,"state","wait of initializing",1);
   	}
   	else{
	   	return "too few parameters: define <name> MagentaTV <Parameter>"; #ToDo Text noch verbessern
   	}
    
  	return undef;
}

sub MagentaTV_StartAccount {
    my ($hash) = @_;
    my $name = $hash->{NAME};

	$hash->{deviceUUID} = MagentaTV_UUID($hash);

	MagentaTV_getCredentials($hash);
	
	if(MagentaTV_setupControlpoint($hash)){
		MagentaTV_startSearch($hash);
	}  	
	
	return undef;
}

sub MagentaTV_StartReceiver {
    my ($hash) = @_;
    my $name = $hash->{NAME};
	
	#nichts zu tun
	
	return undef;
}

sub MagentaTV_Read {
  	my ($hash) = @_;
  	my $name = $hash->{NAME};
  	my $err;
  
  	# $name ist vom Socket!
  
  	my $phash = $hash->{phash};
  	my $cp = $phash->{helper}{controlpoint};
  	
#   	local $SIG{__WARN__} = sub {
#     	my ($called_from) = caller(0);
#     	my $wrn_text = shift;
#     	$wrn_text =~ m/^(.*?)\sat\s.*?$/;
#     	Log3 $name, 1, $phash->{NAME}.": <Read> Socked ".$name." - handleOnce failed: $1";
#     	#Log3 $name, 1, $phash->{NAME}.": <Read> Socked ".$name." - handleOnce failed: called from> ".$called_from.", warn text> ".$wrn_text;
#   	};
  
  	eval {
  		local $SIG{__WARN__} = sub { die $_[0] };
  		
    	$cp->handleOnce($hash->{CD}); #UPnP 1x ausführen, weil etwas auf den Sockets angekommen ist
  	};
  
  	if($@) {
  		$err = $@;
  		$err =~ m/^(.*?)\sat\s(.*?)$/;
  		# ToDo zweite Zeile wieder auf 5
     	Log3 $name, 2, $phash->{NAME}.": <Read> socket ".$name." - handleOnce failed: $1";
     	Log3 $name, 2, $phash->{NAME}.": <Read> socket ".$name." - handleOnce failed at: $2";
  	}
  
   	# Log bei global verbose 5 - Vorsicht, sind evtl. viele Aufrufe durch Multicast!  
  
  	my $socket = $hash->{CD};
	my $self = $cp;
	
	if ($socket == $self->{_searchSocket}) {
		Log3 $name, 5, $phash->{NAME}.": <Read> Socked ".$name." - received search response, $@";
	}
	elsif ($socket == $self->{_ssdpMulticastSocket}) {
		Log3 $name, 5, $phash->{NAME}.": <Read> Socked ".$name." - received ssdp event needed to get information about removed or added devices, $@";
	}
	elsif ($socket == $self->{_subscriptionSocket}) {
		Log3 $name, 5, $phash->{NAME}.": <Read> Socked ".$name." - received event caused by subscription, $@";
	}

  return undef;
}

sub MagentaTV_Shutdown  {
    my ($hash, $arg) = @_; 
	my $name = $hash->{NAME};
	
	Log3 $name, 5, $name.": <Shutdown> Called";
	
	#Logout ACCOUNT 
	MagentaTV_Logout($hash) if ($hash->{SUBTYPE} eq "ACCOUNT");
	
	#kein UNSUBSCIBE senden wenn Subscription Port gesetzt, läuft ins timeout, bzw. der Subscription Port wird wieder benutzt
	if(AttrVal($hash->{NAME}, 'subscriptionPort', 0) == 0 ){
		MagentaTV_StopControlPoint($hash) if ($hash->{SUBTYPE} eq "ACCOUNT");
	}
    
    RemoveInternalTimer($hash);
    
    select(undef, undef, undef, 2);
    
    return undef;
}

sub MagentaTV_DelayedShutdown {
    my ($hash) = @_; 
	my $name = $hash->{NAME};
	
	Log3 $name, 5, $name.": <DelayedShutdown> Called";

    RemoveInternalTimer($hash);
	
	#Logout ACCOUNT 
	MagentaTV_Logout($hash) if ($hash->{SUBTYPE} eq "ACCOUNT");
	
	#kein UNSUBSCIBE senden wenn Subscription Port gesetzt, läuft ins timeout, bzw. der Subscription Port wird wieder benutzt
	if(AttrVal($hash->{NAME}, 'subscriptionPort', 0) == 0 ){
		InternalTimer(gettimeofday()+1, "MagentaTV_StopControlPoint", $hash) if ($hash->{SUBTYPE} eq "ACCOUNT");
		#Time wegen DelayedShutdown
	}
        
    return 1; #Anmeldung, das DelayedShutdown notwendig
}


sub MagentaTV_Undef {
    my ($hash, $arg) = @_; 
	my $name = $hash->{NAME};
	
	Log3 $name, 5, $name.": <Undef> Called ";
    
    BlockingKill($hash->{helper}{RUNNING_PID}) if(exists($hash->{helper}{RUNNING_PID}));
    
    #UNSUBSCIBE senden
    MagentaTV_StopControlPoint($hash) if ($hash->{SUBTYPE} eq "ACCOUNT");
    
    #Logout ACCOUNT
    MagentaTV_Logout($hash) if ($hash->{SUBTYPE} eq "ACCOUNT");
    
    HttpUtils_Close($hash);
   
    RemoveInternalTimer($hash);
    
    select(undef, undef, undef, 1);
    
    return undef;
}

sub MagentaTV_Delete {
	my ($hash, $name) = @_;
	
	Log3 $name, 5, $name.": <Delete> Called ";
	
	#ToDo testen
	if ($hash->{SUBTYPE} eq "ACCOUNT"){
		# Erst alle Receiver löschen
		for my $receiver (MagentaTV_getAllReceiver($hash)) {
			Log3 $name, 5, $name.": <Delete> Called to delete ".$receiver->{NAME};
			CommandDelete(undef, $receiver->{NAME});
		}
		
		#Logout ACCOUNT - erolgt in _Undef
		
		# Etwas warten...
		select(undef, undef, undef, 1);	
	}	

	# Das Entfernen des MagentaTV-Devices selbst übernimmt Fhem
	return undef;
}

sub MagentaTV_Get {
	my ($hash, @param) = @_;
	my $name = $hash->{NAME};
	my $subtype = $hash->{SUBTYPE};
	my $usage = "";	
	my $i;
	my $deviceId;
	
	return '"get $name" needs at least one argument' if (int(@param) < 2);
	
	my $what = $param[1];
	
	if($subtype eq "ACCOUNT"){
		if(AttrVal($name, "expert", 0) == 0){
			$usage = "Unknown argument $what, choose one of DeviceList:noArg showAccount:noArg RefreshChannelInfo:noArg";
		}
		else{
			$usage = "Unknown argument $what, choose one of DeviceList:noArg showAccount:noArg RefreshChannelInfo:noArg showData:Login,Authenticate,Token,DTAuthenticate,HeartBit,DeviceList,SubmitDeviceInfo,ChannelInfo,ReplaceDevice,Logout";
		}
	}
	elsif($subtype eq "RECEIVER"){
		if(AttrVal($name, "expert", 0) == 0){
			$usage = "Unknown argument $what, choose one of RefreshChannelList:noArg";  #"Unknown argument $what, choose one of xxx:noArg";
		}
		else{
			$usage = "Unknown argument $what, choose one of RefreshChannelList:noArg showData:CustomChannels,Favorites,SenderNameList,PlayContext,SubscriptionCallback,getPlayerState,GetTransportInfo,GetTransportSettings,pairingCheck,audioType";
		}
	}
	
	Log3 $name, 5, $name.": <Get> Called for $name : msg = $what";
	
	#ToDo Zustand $hash->{STATE} = "wait of initializing" erkennen.
	
	# ToDo Readings ausgeben
	if ($what =~ /^(state|)$/){
		if(defined($hash->{READINGS}{$what})){
			return $hash->{READINGS}{$what}{VAL};
		}
		else{
			return "no such reading: $what";
		}
	} 
	elsif ($what eq 'showAccount' ){
		my $username = $hash->{helper}{username};
		my $password = $hash->{helper}{password};

		return 'no username set' if( !$username );
		return 'no password set' if( !$password );

		$username = MagentaTV_decrypt( $username );
		$password = MagentaTV_decrypt( $password );

		return "username: $username\npassword: $password";
	}
	elsif ($what eq 'DeviceList' ){
		my @allReceiver = MagentaTV_getAllReceiver($hash);
		my $list = "Found Receiver with UPnP \n";
  		foreach my $ReceiverHash (@allReceiver) {
  			$i++;
    		$list .= $i.": ".$ReceiverHash->{friendlyName}." : ".$ReceiverHash->{UDN}."\n";
    	}
		if(MagentaTV_getDeviceList($hash)){
	    	$list .= "\n";
	    	$list .= "Devicelist of ACCOUNT refreshed at ".POSIX::strftime("%H:%M:%S",localtime(gettimeofday())).". \n";    #POSIX::strftime("%Y%m%d%H%M%S",gmtime(gettimeofday()))
		} 
		else{
	    	$list .= "\n";
	    	$list .= "Devicelist of ACCOUNT not refreshed! \n";
		}   	

    	$list .= "\n";
    	$list .= "Found Receiver (type 0) with ACCOUNT: \n";
    	$i = 0;
  		foreach my $device (@{$hash->{helper}{DeviceList}{deviceList}} ) {
  			if($device->{deviceType} eq "0"){
  				$i++;
				my $deviceName = $device->{terminalVendor};
				$deviceName = $device->{deviceName} if(exists($device->{deviceName}));
				$list .= $i.": ".$deviceName." : online ".$device->{isonline}." : ".$device->{terminalType}." : ".$device->{terminalVendor}." : ".$device->{deviceId}." : ".$device->{physicalDeviceId}."\n";  			
  			}
    	}
    	$list .= "\n";
    	$list .= "Found Clients (type 2) with ACCOUNT: \n";
    	$i = 0;
  		foreach my $device (@{$hash->{helper}{DeviceList}{deviceList}} ) {
			if($device->{deviceType} eq "2"){
  				$i++;
				my $deviceName = $device->{terminalVendor};
				$deviceName = $device->{deviceName} if(exists($device->{deviceName}));
				$list .= $i.": ".$deviceName." : online ".$device->{isonline}." : ".$device->{terminalType}." : ".$device->{terminalVendor}." : ".$device->{deviceId}." : ".$device->{physicalDeviceId}."\n";
    		}
    	}
		return $list;
  	}
  	elsif ($what eq 'RefreshChannelInfo' ){
  		MagentaTV_getChannelInfo($hash);
  		my $data = $hash->{channels}." channels found.";
  		return $data;
  	}
  	elsif ($what eq 'RefreshChannelList' ){
  		MagentaTV_getSender($hash);
  		my $data = $hash->{channelsVisible}." visible channels found.\n";
  		$data   .= $hash->{channelsFavorit}." favorit channels found.";
  		return $data;
  	}
	elsif ($what eq 'showData' ){
		my $dump;
		if($param[2] eq "Login"){
			if(exists($hash->{helper}{Login})){
				$dump = Dumper($hash->{helper}{Login});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				#$dump = "ChannelInfo of ACCOUNT refreshed at ".$hash->{helper}{ChannelInfo}{timestampLastRead}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "Authenticate"){
			if(exists($hash->{helper}{Authenticate})){
				$dump = Dumper($hash->{helper}{Authenticate});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				#$dump = "ChannelInfo of ACCOUNT refreshed at ".$hash->{helper}{ChannelInfo}{timestampLastRead}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "Token"){
			if(exists($hash->{helper}{Token})){
				$dump = Dumper($hash->{helper}{Token});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				#$dump = "ChannelInfo of ACCOUNT refreshed at ".$hash->{helper}{ChannelInfo}{timestampLastRead}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "DTAuthenticate"){
			if(exists($hash->{helper}{DTAuthenticate})){
				$dump = Dumper($hash->{helper}{DTAuthenticate});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				#$dump = "ChannelInfo of ACCOUNT refreshed at ".$hash->{helper}{ChannelInfo}{timestampLastRead}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "HeartBit"){
			if(exists($hash->{helper}{HeartBit})){
				$dump = Dumper($hash->{helper}{HeartBit});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				#$dump = "ChannelInfo of ACCOUNT refreshed at ".$hash->{helper}{ChannelInfo}{timestampLastRead}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "DeviceList"){
			if(exists($hash->{helper}{DeviceList})){
				$dump = Dumper($hash->{helper}{DeviceList});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				#$dump = "ChannelInfo of ACCOUNT refreshed at ".$hash->{helper}{ChannelInfo}{timestampLastRead}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "SubmitDeviceInfo"){
			if(exists($hash->{helper}{SubmitDeviceInfo})){
				$dump = Dumper($hash->{helper}{SubmitDeviceInfo});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				#$dump = "ChannelInfo of ACCOUNT refreshed at ".$hash->{helper}{ChannelInfo}{timestampLastRead}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "ChannelInfo"){
			if(exists($hash->{helper}{ChannelInfo})){
				$dump = Dumper($hash->{helper}{ChannelInfo});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				#$dump = "ChannelInfo of ACCOUNT refreshed at ".$hash->{helper}{ChannelInfo}{timestampLastRead}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "ReplaceDevice"){
			if(exists($hash->{helper}{ReplaceDevice})){
				$dump = Dumper($hash->{helper}{ReplaceDevice});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				#$dump = "ReplaceDevice of ACCOUNT refreshed at ".$hash->{helper}{ReplaceDevice}{timestampLastRead}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "Logout"){
			if(exists($hash->{helper}{Logout})){
				$dump = Dumper($hash->{helper}{Logout});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				#$dump = "Logout of ACCOUNT refreshed at ".$hash->{helper}{Logout}{timestampLastRead}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "CustomChannels"){
			if(exists($hash->{helper}{CustomChannels})){
				$dump = Dumper($hash->{helper}{CustomChannels}{value});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				$dump = "CustomChannels of RECEIVER refreshed at ".$hash->{helper}{CustomChannels}{timestamp}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "Favorites"){
			if(exists($hash->{helper}{Favorites})){
				$dump = Dumper($hash->{helper}{Favorites}{value});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				$dump = "Favorites of RECEIVER refreshed at ".$hash->{helper}{Favorites}{timestamp}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "SenderNameList"){
			if(exists($hash->{helper}{senderNameList})){
				$dump = Dumper($hash->{helper}{senderNameList});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				#$dump = "SenderNameList of RECEIVER refreshed at ".$hash->{helper}{senderNameList}{timestamp}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "PlayContext"){
			if(exists($hash->{helper}{PlayBillContextEx})){
				$dump = Dumper($hash->{helper}{PlayBillContextEx}{value});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				$dump = "PlayContext of RECEIVER refreshed at ".$hash->{helper}{PlayBillContextEx}{timestamp}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "SubscriptionCallback"){
			if(exists($hash->{helper}{subscriptionCallback})){
				$dump = Dumper($hash->{helper}{subscriptionCallback});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				#$dump = "SubscriptionCallback of RECEIVER refreshed at ".$hash->{helper}{SubscriptionCallback}{timestamp}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "audioType"){
			if(exists($hash->{helper}{audioType})){
				$dump = Dumper($hash->{helper}{audioType});
				$dump =~ s{\A\$VAR\d+\s*=\s*}{};
				#$dump = "audioType of RECEIVER refreshed at ".$hash->{helper}{ChannelInfo}{audioType}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "getPlayerState"){
			MagentaTV_getPlayerState($hash);
			if(exists($hash->{helper}{getPlayerState})){
				$dump = encode_entities($hash->{helper}{getPlayerState});
				#$dump = "getPlayerState of RECEIVER refreshed at ".$hash->{helper}{getPlayerState}{timestamp}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "GetTransportInfo"){
			MagentaTV_GetTransportInfo($hash);
			if(exists($hash->{helper}{GetTransportInfo})){
				$dump = encode_entities($hash->{helper}{GetTransportInfo});
				#$dump = "GetTransportInfo of RECEIVER refreshed at ".$hash->{helper}{GetTransportInfo}{timestamp}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "GetTransportSettings"){
			MagentaTV_GetTransportSettings($hash);
			if(exists($hash->{helper}{GetTransportSettings})){
				$dump = encode_entities($hash->{helper}{GetTransportSettings});
				#$dump = "GetTransportSettings of RECEIVER refreshed at ".$hash->{helper}{GetTransportSettings}{timestamp}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
		elsif($param[2] eq "pairingCheck"){
			if(exists($hash->{helper}{pairingCheck})){
				$dump = encode_entities($hash->{helper}{pairingCheck});
				#$dump = "pairingCheck of RECEIVER refreshed at ".$hash->{helper}{pairingCheck}{timestamp}.".\n\n".$dump; 
				return $dump;
			}
			else{return "no data"}
		}
	}
	
	return $usage; 
}

sub MagentaTV_Set {
	my ($hash, @param) = @_;
	my $name = $hash->{NAME};
	my $subtype = $hash->{SUBTYPE};
	my $usage = "";	
	my $channelList = "NONE";
	my $chanNoList = "NONE";
	my $deviceList = "NONE";
	my $physicalDeviceId = "NONE";
	
	return '"set $name" needs at least one argument' if (int(@param) < 2);
	
	my $what = $param[1];

	Log3 $name, 5, $name.": <Set> Called for $name : msg = $what";
	
	if($subtype eq "ACCOUNT"){
  		if(exists($hash->{helper}{DeviceList}{deviceList})){
  			$deviceList = '';
  			$physicalDeviceId = $hash->{deviceUUID};
  			$physicalDeviceId .= ',';
	  		foreach my $device (@{$hash->{helper}{DeviceList}{deviceList}} ) {
				if($device->{deviceType} eq "2"){
					$deviceList .= $device->{deviceId}.",";
					$physicalDeviceId .= $device->{physicalDeviceId}.",";
	    		}
	    	}
			$deviceList 		=~ s/,$//g; 		#letztes Komma wieder weg
			$physicalDeviceId 	=~ s/,$//g; 
		}
		$usage = "Unknown argument $what, choose one of RefreshCredentials:noArg RescanNetwork:noArg Logout:noArg";
		
		if(AttrVal($name,"expert",0)){$usage .= " StartUpnpSearch:noArg RefreshChannelList:noArg RefreshDeviceList:noArg ReplaceDevice:".$deviceList." SetPhysicalDeviceId:".$physicalDeviceId};
	}
	elsif($subtype eq "RECEIVER"){
	
		#ToDo Zustand $hash->{STATE} = "wait of initializing" erkennen.
		my $list = join(',', map {"$_"} sort keys %keyMap);
		
		if(exists($hash->{helper}{senderNameListSet})){
			$channelList = $hash->{helper}{senderNameListSet};
		}
		if(exists($hash->{helper}{chanNoListSet})){
			$chanNoList = $hash->{helper}{chanNoListSet};
		}
		
		$usage = "Unknown argument $what, choose one of on:noArg off:noArg toggle:noArg Play:noArg Pause:noArg Rewind:noArg Forward:noArg OK:noArg Back:noArg Exit:noArg EPG:noArg volumeUp:noArg volumeDown:noArg Mute:noArg channelUp:noArg channelDown:noArg Channel:".$chanNoList." ChannelName:".$channelList." SendKey:".$list;

		if(AttrVal($name,"expert",0)){$usage .= " OpenApp"};
	}

	if ($what =~ /^(on|off|toggle)$/){
		if($what eq "on"){
			MagentaTV_RemoteKey($hash, "ON");
		}
		elsif($what eq "off"){
			MagentaTV_RemoteKey($hash, "OFF");
		}
		elsif($what eq "toggle"){
			MagentaTV_RemoteKey($hash, "POWER");
		}
		Log3 $name, 3, $name.": set $name $what";
		return (undef, 1);
	}
	elsif($what eq "Play"){
		MagentaTV_RemoteKey($hash, "PLAY") if(($hash->{READINGS}{newPlayMode}{VAL} eq "STOP") || ($hash->{READINGS}{newPlayMode}{VAL} eq "PAUSE"));
		return (undef, 1);
	}
	elsif($what eq "Pause"){
		MagentaTV_RemoteKey($hash, "PAUSE") if($hash->{READINGS}{newPlayMode}{VAL} =~ /^PLAY/);
		return (undef, 1);
	}
	elsif($what eq "OK"){
		MagentaTV_RemoteKey($hash, "OK");
		return (undef, 1);
	}
	elsif($what eq "Back"){
		MagentaTV_RemoteKey($hash, "BACK");
		return (undef, 1);
	}
	elsif($what eq "Exit"){
		MagentaTV_RemoteKey($hash, "EXIT");
		return (undef, 1);
	}
	elsif($what eq "volumeUp"){
		MagentaTV_RemoteKey($hash, "VOLUP");
		return (undef, 1);
	}
	elsif($what eq "volumeDown"){
		MagentaTV_RemoteKey($hash, "VOLDOWN");
		return (undef, 1);
	}
	elsif($what eq "Mute"){
		MagentaTV_RemoteKey($hash, "MUTE");
		return (undef, 1);
	}
	elsif($what eq "channelUp"){
		MagentaTV_RemoteKey($hash, "CHUP");
		return (undef, 1);
	}
	elsif($what eq "channelDown"){
		MagentaTV_RemoteKey($hash, "CHDOWN");
		return (undef, 1);
	}
	elsif($what eq "Rewind"){
		MagentaTV_RemoteKey($hash, "REWIND");
		return (undef, 1);
	}
	elsif($what eq "Forward"){
		MagentaTV_RemoteKey($hash, "FORWARD");
		return (undef, 1);
	}
	elsif($what eq "EPG"){
		MagentaTV_RemoteKey($hash, "EPG");
		return (undef, 1);
	}
	elsif($what eq "RefreshCredentials"){
		MagentaTV_getCredentials($hash);
		return (undef, 1);
	}
	elsif($what eq "RefreshChannelList"){
		MagentaTV_getChannelInfo($hash);
		return (undef, 1);
	}
	elsif($what eq "RefreshDeviceList"){
		MagentaTV_getDeviceList($hash);
		return (undef, 1);
	}
	elsif($what eq "Logout"){
		MagentaTV_Logout($hash);
		return (undef, 1);
	}	
	elsif($what eq "RescanNetwork"){
		MagentaTV_rescanNetwork($hash);
		return (undef, 1);
	}
	elsif($what eq "StartUpnpSearch"){
		MagentaTV_startSearch($hash);
		return (undef, 1);
	}
	elsif($what eq "SendKey"){
		if(defined($keyMap{trim($param[2])})){
			MagentaTV_RemoteKey($hash, trim($param[2]));
			return (undef, 1);
		}
		else{
			return "Wrong keycode for SendKey!";
		}
	}
	elsif($what eq "Channel"){
 		if (trim($param[2]) =~ qr/^[0-9]{1,4}$/) {
 			my $channel = MagentaTV_chanNo2channel($hash,trim($param[2]));
			if(defined($channel)){
				MagentaTV_changeChannel($hash, $channel);
				return (undef, 1);
			}
 			return "Wrong argument for Channel!";
 		}
 		else{
			return "Wrong argument for Channel!";
		}
	}	
	elsif($what eq "ChannelName"){
		splice (@param, 0, 2);
		my $channelName = join " ",@param;
		$channelName =~ s/\x{00C2}\x{00A0}/ /g; #kommt von den &nbsp; im Pulldownmenü
		my $channel = MagentaTV_senderName2channel($hash,$channelName);
		if(defined($channel)){
			MagentaTV_changeChannel($hash, $channel);
			return (undef, 1);
		}
		else{
			return 'Wrong ChannelName "'.$channelName.'" !';
		}
	}
	elsif($what eq "ReplaceDevice"){
 		if (trim($param[2]) =~ qr/^[0-9]+$/) {
 			MagentaTV_ReplaceDevice($hash, trim($param[2]));
			return (undef, 1);
 		}
 		else{
			return "Wrong argument ".trim($param[2])." for $what !";
		}
	}	
	elsif($what eq "SetPhysicalDeviceId"){
 		readingsSingleUpdate($hash,"physicalDeviceId",trim($param[2]),1);
		return (undef, 1);
 	}
	elsif($what eq "OpenApp"){
 		MagentaTV_OpenApp($hash, trim($param[2]));
		return (undef, 1);
 	}
 	
	return $usage;
}

sub MagentaTV_Attr {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	# $cmd can be "del" or "set"
	# $name is device name
	# $attr_name and $attr_value are Attribute name and value
	my $hash = $main::defs{$name};
	
	$attr_value = "" if (!defined $attr_value);
	
	Log3 $name, 5, $name.": <Attr> Called for $attr_name : value = $attr_value";
	
	if($cmd eq "set") {
        if($attr_name eq "xxx") {
			# value testen
			#if($attr_value !~ /^yes|no$/) {
			#    my $err = "Invalid argument $attr_value to $attr_name. Must be yes or no.";
			#    Log 3, "MagentaTV: ".$err;
			#    return $err;
			#}
		}
		elsif($attr_name eq "ignoredIPs") {
			# value testen
		
		} 
		elsif($attr_name eq "usedonlyIPs") {
			# value testen
		
		} 
		elsif($attr_name eq "ignoreUDNs") {
			# value testen
		
		} 
		elsif($attr_name eq "acceptedUDNs") {
			# value testen
		
		} 
		elsif($attr_name eq "subscriptionPort") {
			unless ($attr_value =~ qr/^[0-9]+$/) {
				Log3 $name, 2, $name.": Invalid Port in attr $attr_name : $attr_value";
				return "Invalid Port $attr_value";
			} 
		} 
		elsif($attr_name eq "searchPort") {
			unless ($attr_value =~ qr/^[0-9]+$/) {
				Log3 $name, 2, $name.": Invalid Port in attr $attr_name : $attr_value";
				return "Invalid Port $attr_value";
			} 
		} 
		elsif($attr_name eq "getPlayerStateInterval") {
			unless ($attr_value =~ qr/^[0-9]+$/) {
				Log3 $name, 2, $name.": Invalid Time in attr $attr_name : $attr_value";
				return "Invalid Time $attr_value";
			} 
			if(ReadingsVal($name,"pairing","none") eq "paired"){
				InternalTimer(gettimeofday() + ($attr_value * 60), "MagentaTV_getPlayerState", $hash) if($attr_value);
			}
		} 
		elsif($attr_name eq "RescanNetworkInterval") {
			unless ($attr_value =~ qr/^[0-9]+$/) {
				Log3 $name, 2, $name.": Invalid Time in attr $attr_name : $attr_value";
				return "Invalid Time $attr_value";
			} 
			InternalTimer(gettimeofday() + ($attr_value * 60) + 10 * 60, "MagentaTV_rescanNetwork", $hash) if($attr_value); # +10min wegen Startphase überbrücken
		} 
		elsif($attr_name eq "renewSubscription") {
			unless (($attr_value =~ qr/^[0-9]{2,3}$/) && ($attr_value >= 60) && ($attr_value <= 300)) {
				Log3 $name, 2, $name.": Invalid Time in attr $attr_name : $attr_value";
				return "Invalid Time $attr_value";
			} 
			$hash->{helper}{keepalive} = $attr_value;
		}
		elsif($attr_name eq "SenderListType") {
			unless (($attr_value eq "custom") || ($attr_value eq "favorit")) {
				Log3 $name, 2, $name.": Invalid parameter in attr $attr_name : $attr_value";
				return "Invalid parameter $attr_value";
			} 
			if(ReadingsVal($name,"pairing","none") eq "paired"){
				InternalTimer(gettimeofday() + 5, "MagentaTV_getSender", $hash);
			}
		}
		elsif($attr_name eq "PrograminfoReadings") {
			if($attr_value == 0){
				delPrograminfReadings($hash);
			}
		} 

	}
	elsif($cmd eq "del"){
		#default wieder herstellen
		if($attr_name eq "PrograminfoReadings") {
			MagentaTV_delPrograminfoReadings($hash); 
		} 
		if($attr_name eq "getPlayerStateInterval") {
			RemoveInternalTimer($hash, "MagentaTV_getPlayerState"); 
		} 
		if($attr_name eq "RescanNetworkInterval") {
			RemoveInternalTimer($hash, "MagentaTV_rescanNetwork");  
		} 
	
	}
	return undef;
}

sub MagentaTV_delPrograminfoReadings {
	my ($hash) = @_;
	
	readingsDelete($hash,"currentProgramDuration");
	readingsDelete($hash,"currentProgramStart");
	readingsDelete($hash,"currentProgramTime");
	readingsDelete($hash,"currentProgramStatus");
	readingsDelete($hash,"currentProgramTitle");
	readingsDelete($hash,"currentProgramGenre");
	readingsDelete($hash,"nextProgramDuration");
	readingsDelete($hash,"nextProgramStart");
	readingsDelete($hash,"nextProgramTime");
	readingsDelete($hash,"nextProgramStatus");
	readingsDelete($hash,"nextProgramTitle");
	readingsDelete($hash,"nextProgramGenre");
	
	return;
}

sub MagentaTV_TriggerDetailFn {
	my ($hash) = @_;
	
	my $html = MagentaTV_detailFn('', $hash->{NAME}, '', 1);
	DoTrigger($hash->{NAME}, 'display_covertitle: '.$html, 1);
	
	return undef;
}

sub MagentaTV_detailFn {
  	my ($FW_wname, $name, $room, $withRC) = @_; 
  	my $hash = $defs{$name};
  	$withRC = 1 if (!defined($withRC));
  	my $on = 0;

    Log3 $name, 5, $name.": <detailFn> Called ";

    return undef if(($hash->{SUBTYPE} eq "ACCOUNT") || ($hash->{SUBTYPE} eq "UPnPSocket"));
    
	if(($hash->{SUBTYPE} eq "RECEIVER") && (($hash->{STATE} eq "play") || ($hash->{STATE} eq "pause"))){
		$on = 1;
	}

	# Open incl. Inform-Div
	my $html .= '<html><div informid="'.$name.'-display_covertitle" style="padding: 0px; margin: 0px;">';

	# Control-Buttons
	if (AttrVal($name, "ControlButtons", 1) && ($withRC)) {
		$html .= '<div class="rc_body" style="margin-bottom: 5px; border: 1px solid gray; border-radius: 10px; padding: 5px;">';
		$html .= '<table style="text-align: center;"><tr>';

			$html .= '<td><a style="padding-left: 10px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' OK\')">'.FW_makeImage('rc_OK.svg', 'OK', 'rc-button').'</a></td>'; 
			$html .= '<td><a style="padding-left: 10px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' Exit\')">'.FW_makeImage('rc_EXIT.svg', 'Exit', 'rc-button').'</a></td>'; 
			$html .= '<td><a style="padding-left: 10px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' Back\')">'.FW_makeImage('rc_BACK.svg', 'Back', 'rc-button').'</a></td>'; 
			$html .= '<td><a style="padding-left: 10px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' EPG\')">'.FW_makeImage('rc_EPG.svg', 'EPG', 'rc-button').'</a></td>'; 

			$html .= '<td style="padding-left: 30px;">'.FW_makeImage('rc_VOL.svg', 'VOL', 'rc-button').'</td>'; 
			$html .= '<td><a style="padding-left: 10px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' volumeDown\')">'.FW_makeImage('rc_VOLDOWN.svg', 'VolDown', 'rc-button').'</a></td>';
			$html .= '<td><a style="padding-left: 10px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' Mute\')">'.FW_makeImage('rc_MUTE.svg', 'Mute', 'rc-button').'</a></td>';
			$html .= '<td><a style="padding-left: 10px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' volumeUp\')">'.FW_makeImage('rc_VOLUP.svg', 'VolUp', 'rc-button').'</a></td>';

			$html .= '<td style="padding-left: 30px;">'.FW_makeImage('rc_PROG.svg', 'PROG', 'rc-button').'</td>'; 
			$html .= '<td><a style="padding-left: 10px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' channelDown\')">'.FW_makeImage('rc_PREVIOUS.svg', 'Previous', 'rc-button').'</a></td>'; 
			$html .= '<td><a style="padding-left: 10px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' channelUp\')">'.FW_makeImage('rc_NEXT.svg', 'Next', 'rc-button').'</a></td>'; 

			$html .= '<td><a style="padding-left: 30px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' Rewind\')">'.FW_makeImage('rc_REW.svg', 'Rewind', 'rc-button').'</a></td>'; 
			$html .= '<td><a style="padding-left: 10px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' on\')">'.FW_makeImage('control_home.svg', 'Offline', 'rc-button').'</td>' if ((ReadingsVal($name, 'state', 'offline') eq 'offline') || (ReadingsVal($name, 'state', 'offline') eq 'online') || (ReadingsVal($name, 'state', 'offline') eq 'standby'));
			$html .= '<td><a style="padding-left: 10px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' Pause\')">'.FW_makeImage('rc_PLAY.svg', 'Play', 'rc-button').'</a></td>' if (ReadingsVal($name, 'state', 'offline') eq 'play');
			$html .= '<td><a style="padding-left: 10px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' Play\')">'.FW_makeImage('rc_PAUSE.svg', 'Pause', 'rc-button').'</a></td>' if (ReadingsVal($name, 'state', 'offline') eq 'pause');
			$html .= '<td><a style="padding-left: 10px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' Forward\')">'.FW_makeImage('rc_FF.svg', 'Forward', 'rc-button').'</a></td>'; 

#			$html .= '<td style="padding-left: 40px;">'.FW_makeImage('control_home.svg', 'Offline', 'rc-button').'</td>' if (ReadingsVal($name, 'state', 'offline') eq 'offline');
			$html .= '<td><a style="padding-left: 40px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' on\')">'.FW_makeImage('control_home.svg', 'Offline', 'rc-button').'</td>' if (ReadingsVal($name, 'state', 'offline') eq 'offline');
			$html .= '<td style="padding-left: 40px;">'.FW_makeImage('control_on_off.svg', 'Online', 'rc-button').'</td>' if (ReadingsVal($name, 'state', 'Online') eq 'online');
			$html .= '<td><a style="padding-left: 40px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' on\')">'.FW_makeImage('control_standby@red', 'Standby', 'rc-button').'</a></td>' if (ReadingsVal($name, 'state', 'offline') eq 'standby');
			$html .= '<td><a style="padding-left: 40px;" onclick="FW_cmd(\'?XHR=1&amp;cmd.dummy=set '.$name.' off\')">'.FW_makeImage('control_standby@gray', 'On', 'rc-button').'</a></td>' if ((ReadingsVal($name, 'state', 'offline') eq 'play') || (ReadingsVal($name, 'state', 'offline') eq 'pause'));

		$html .= '</tr></table>';
		$html .= '</div>';
	}

	
	# Cover-/TitleView current Program
	if(AttrVal($name,"Programinfo",1)){
		$html .= '<div style="margin-bottom: 5px; border: 1px solid gray; border-radius: 10px; padding: 5px;">';
	 	$html .= MagentaTV_getCoverTitle($name, 0, $on);
		$html .= '</div>';
	}

	# Cover-/TitleView next Program
	if(AttrVal($name,"PrograminfoNext",1)){
		# Cover-/TitleView nextProgram
		$html .= '<div style="margin-bottom: 5px; border: 1px solid gray; border-radius: 10px; padding: 5px;">';
	 	$html .= MagentaTV_getCoverTitle($name, 1, $on);
		$html .= '</div>';	
	}
	# Close Inform-Div
	$html .= '</div>';
	
	# Close
	$html .= '</html>';
	
	return $html;
}

sub MagentaTV_getCoverTitle { 
	my ($device, $next, $on) = @_;
	my $width = 500 ;
	my $html;
	
	$html .= '	<table cellpadding="0" cellspacing="0" style="padding: 0px; margin: 0px;">
					<tr>
						<td valign="top" style="padding: 0px; margin: 0px;">
							<div style="" >'.MagentaTV_getCover($device, $next, $on).'</div>
						</td>
						<td valign="top" style="padding: 0px; margin: 0px;">
							<div style="margin-left: 0px; min-width: '.$width.'px;">'.MagentaTV_getTitle($device, $next, $on).'</div>
						</td>
					</tr>
				</table>';
				
	$html =~ s/\n/ /g;
	
	return $html;
}

sub MagentaTV_getCover {
	my ($device, $next, $on) = @_;
	my $hash = $defs{$device};

 	my $width = '172';		#'10.75em'; #172 
	my $height = '96';		#'6.00em'; #96
	my $poster = "data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjEyMCIgd2lkdGg9IjEyMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cGF0aCBkPSJNMzQgMTA1di0yLjNjMC0xLjUgMS43LTIuNyAzLjctMi43aDQ0LjZjMiAwIDMuNyAxLjIgMy43IDIuN3YyLjN6bTc4LjMtODdINy43Yy0yIDAtMy43IDEuNi0zLjcgMy42djY2LjdjMCAyIDEuNyAzLjYgMy43IDMuNkg1MXY0aDE4di00aDQzLjNjMi4xIDAgMy43LTEuNiAzLjctMy42VjIxLjZjMC0yLTEuNy0zLjYtMy43LTMuNnpNMTEwIDg2SDEwVjI0aDEwMHoiIGZpbGw9IiNCREJEQkQiLz48L3N2Zz4=";
#	my $poster = q['data:image/svg+xml;utf8,<svg width="120" height="120"><path fill="#BDBDBD" fill-rule="evenodd" d="M34 105v-2.3c0-1.5 1.7-2.7 3.7-2.7h44.6c2 0 3.7 1.2 3.7 2.7v2.3zm78.3-87H7.7c-2 0-3.7 1.6-3.7 3.6v66.7c0 2 1.7 3.6 3.7 3.6H51v4h18v-4h43.3c2.1 0 3.7-1.6 3.7-3.6V21.6c0-2-1.7-3.6-3.7-3.6zM110 86H10V24h100z"/></svg>'];
	
	# Umwandlung von svg in Base64 (einfacher zu handhaben)
	# https://base64.guru/converter/encode/image/svg

	my $logo = '';
	my ($type,$pictures);

	if($on){
		if($next){
			if(exists($hash->{helper}{EPG}{nextList}{pictures})){
				($type,$pictures) = MagentaTV_pictures($hash,$hash->{helper}{EPG}{nextList}{pictures});
				if(defined($pictures)){
					$poster = "https://ngiss.t-online.de/iss?client=ngtv&y=".$height."&x=".$width."&ar=keep&src=".$pictures;
				}
			}
		}
		else{
			if(exists($hash->{helper}{EPG}{current}{pictures})){
				($type,$pictures) = MagentaTV_pictures($hash,$hash->{helper}{EPG}{current}{pictures});
				if(defined($pictures)){
					$poster = "https://ngiss.t-online.de/iss?client=ngtv&y=".$height."&x=".$width."&ar=keep&src=".$pictures;
				}			
			}
		}
	
		if(defined($type)){	
			if($type ne "20"){
				if(defined($hash->{helper}{EPG}{logo})){$logo = "https://ngiss.t-online.de/iss?client=ngtv&y=16&ar=keep&src=".$hash->{helper}{EPG}{logo}}
			}	
		}		
	}
	
	my $html = '	<div informid="'.$device.'-display_covertitle">
						<div style="display: inline-block; margin-right: 5px; border: 1px solid lightgray; height: '.$height.'px; width: '.$width.'px; background-color: #424242; background-image: url('.$poster.'); background-repeat: no-repeat; background-size: contain; background-position: center center;">
							<div style="position: relative; top: 4px; left: 4px; display: inline-block; height: 16px; width: 40px; background-image: url('.$logo.'); background-repeat: no-repeat; background-size: contain; background-position: center center;"></div>
						</div>
					</div>';
	
	$html =~ s/\n/ /g; 
	
	return $html;
}

sub MagentaTV_getTitle {
	my ($device, $next, $on) = @_;
	my $hash = $defs{$device};
	
	my $sendername 	= 'Sender';
	my $chanNo 		= 'Kanal';
	my $fav			= '';
	my $name 		= 'Programminfo';
	my $genres 		= 'Genres';
	my $time		= 'Datum | Begin - Ende | Laufzeit';
	my $format		= '';
	my ($mix,$coding);
	my $audio		= '';
	
	my $html		= '';
	
	my $favPic		= "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCI+PHBhdGggZmlsbD0iI0JEQkRCRCIgZmlsbC1ydWxlPSJldmVub2RkIiBkPSJNMTYuMjA2IDRhNC40NiA0LjQ2IDAgMCAxIDQuNDYgNC40NmMwIDYuODA5LTguODMzIDEyLjAwNS04LjgzMyAxMi4wMDVTMyAxNS4yNyAzIDguNDZhNC40NiA0LjQ2IDAgMCAxIDguODMzLS44NzZBNC40NjEgNC40NjEgMCAwIDEgMTYuMjA2IDR6Ii8+PC9zdmc+";
#	my $favPic		= '\'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><g><path fill="#BDBDBD" fill-rule="evenodd" d="M16.206 4a4.46 4.46 0 0 1 4.46 4.46c0 6.809-8.833 12.005-8.833 12.005S3 15.27 3 8.46a4.46 4.46 0 0 1 8.833-.876A4.461 4.461 0 0 1 16.206 4z"/></g></svg>\'';
	
	if($on){
		if($next){
			if(defined($hash->{helper}{EPG}{sendername})){$sendername = $hash->{helper}{EPG}{sendername}};
			$chanNo = ReadingsVal($device,"chanNo","Kanal");
			$fav 	= (ReadingsVal($device,"favorite",0) == 1) ? '<img src='.$favPic.' width="11" height="11">' : '';
			if(defined($hash->{helper}{EPG}{nextList}{name})){$name = $hash->{helper}{EPG}{nextList}{name}};
			if(defined($hash->{helper}{EPG}{nextList}{genres})){$genres = $hash->{helper}{EPG}{nextList}{genres}};
			if((defined($hash->{helper}{EPG}{nextList}{starttime})) && (defined($hash->{helper}{EPG}{nextList}{endtime}))){$time = MagentaTV_timePrint($hash->{helper}{EPG}{nextList}{starttime},$hash->{helper}{EPG}{nextList}{endtime})};		
			if(defined($hash->{helper}{EPG}{format})){$format = $hash->{helper}{EPG}{format}};
			if(defined($hash->{helper}{EPG}{nextList}{audioAttribute})){($mix,$coding) = MagentaTV_audioType($hash,$hash->{helper}{EPG}{nextList}{audioAttribute})};
		}
		else{
			if(defined($hash->{helper}{EPG}{sendername})){$sendername = $hash->{helper}{EPG}{sendername}};
			$chanNo = ReadingsVal($device,"chanNo","Kanal");
			$fav 	= (ReadingsVal($device,"favorite",0) == 1) ? '<img src='.$favPic.' width="11" height="11">' : '';
			if(defined($hash->{helper}{EPG}{current}{name})){$name = $hash->{helper}{EPG}{current}{name}};
			if(defined($hash->{helper}{EPG}{current}{genres})){$genres = $hash->{helper}{EPG}{current}{genres}};
			if((defined($hash->{helper}{EPG}{current}{starttime})) && (defined($hash->{helper}{EPG}{current}{endtime}))){$time = MagentaTV_timePrint($hash->{helper}{EPG}{current}{starttime},$hash->{helper}{EPG}{current}{endtime})};		
			if(defined($hash->{helper}{EPG}{format})){$format = $hash->{helper}{EPG}{format}};
			if(defined($hash->{helper}{EPG}{current}{audioAttribute})){($mix,$coding) = MagentaTV_audioType($hash,$hash->{helper}{EPG}{current}{audioAttribute})};
		}
	}

	$html = sprintf('<div style="display: inline-block; padding: 0px; margin: 0px;"><b>%s</b> | <small>%s %s</small><br /><b>%s</b><br /><b>%s</b><br /><b>%s</b></div>',
		$sendername,
		$chanNo,
		$fav,
		encode('utf-8', $name),
		encode('utf-8', $genres),
		$time );
	
	if($format eq "SD"){
		$format = "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIj8+CjxzdmcgdmVyc2lvbj0iMS4xIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB3aWR0aD0iNjQwIiBoZWlnaHQ9IjQ4MCI+CiAgICA8ZGVzYyBpVmluY2k9InllcyIgdmVyc2lvbj0iNC42IiBncmlkU3RlcD0iMjAiIHNob3dHcmlkPSJubyIgc25hcFRvR3JpZD0ibm8iIGNvZGVQbGF0Zm9ybT0iMCIvPgogICAgPGcgaWQ9IkxheWVyMSIgbmFtZT0iTGF5ZXIgMSIgb3BhY2l0eT0iMSI+CiAgICAgICAgPGcgaWQ9IlNoYXBlMSI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjEiIHR5cGU9IjAiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjIiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMTY5LC0xMTYuNSwzMzgsMjMzKSIgdGV4dD0iIiBmb250LWZhbWlseU5hbWU9IkhlbHZldGljYSIgZm9udC1waXhlbFNpemU9IjIwIiBmb250LWJvbGQ9IjAiIGZvbnQtdW5kZXJsaW5lPSIwIiBmb250LWFsaWdubWVudD0iMSIgc3Ryb2tlU3R5bGU9IjAiIG1hcmtlclN0YXJ0PSIwIiBtYXJrZXJFbmQ9IjAiIHNoYWRvd0VuYWJsZWQ9IjAiIHNoYWRvd09mZnNldFg9IjAiIHNoYWRvd09mZnNldFk9IjIiIHNoYWRvd0JsdXI9IjQiIHNoYWRvd09wYWNpdHk9IjE2MCIgYmx1ckVuYWJsZWQ9IjAiIGJsdXJSYWRpdXM9IjQiIHRyYW5zZm9ybT0ibWF0cml4KDEuODkzNDksMCwwLDIuMDYwMDksMzIwLDI0MCkiIHBlcnMtY2VudGVyPSIwLDAiIHBlcnMtc2l6ZT0iMCwwIiBwZXJzLXN0YXJ0PSIwLDAiIHBlcnMtZW5kPSIwLDAiIGxvY2tlZD0iMCIgbWVzaD0iIiBmbGFnPSIiLz4KICAgICAgICAgICAgPHBhdGggaWQ9InNoYXBlUGF0aDEiIGQ9Ik0wLDI0LjcyMTEgQzAsMTEuMDY4OSAxMC4xNzM3LDEuNTI1ODhlLTA1IDIyLjcyMTksMS41MjU4OGUtMDUgTDYxNy4yNzgsMS41MjU4OGUtMDUgQzYyOS44MjYsMS41MjU4OGUtMDUgNjQwLDExLjA2ODkgNjQwLDI0LjcyMTEgTDY0MCw0NTUuMjc5IEM2NDAsNDY4LjkzMSA2MjkuODI2LDQ4MCA2MTcuMjc4LDQ4MCBMMjIuNzIxOSw0ODAgQzEwLjE3MzcsNDgwIDAsNDY4LjkzMSAwLDQ1NS4yNzkgTDAsMjQuNzIxMSBaIiBzdHlsZT0ic3Ryb2tlOiMzMjMyMzI7c3Ryb2tlLW9wYWNpdHk6MTtzdHJva2Utd2lkdGg6MTtzdHJva2UtbGluZWpvaW46bWl0ZXI7c3Ryb2tlLW1pdGVybGltaXQ6MjtzdHJva2UtbGluZWNhcDpyb3VuZDtmaWxsLXJ1bGU6ZXZlbm9kZDtmaWxsOiM5Njk2OTY7ZmlsbC1vcGFjaXR5OjE7Ii8+CiAgICAgICAgPC9nPgogICAgPC9nPgogICAgPGcgaWQ9IkxheWVyMiIgbmFtZT0iTGF5ZXIgMiIgb3BhY2l0eT0iMSI+CiAgICAgICAgPGcgaWQ9IlNoYXBlMiI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjIiIHR5cGU9IjIiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjAiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMzA2LjUsLTE5NC41LDYxMywzODkpIiB0ZXh0PSJTRCIgZm9udC1mYW1pbHlOYW1lPSJIZWx2ZXRpY2EiIGZvbnQtcGl4ZWxTaXplPSIyODAiIGZvbnQtYm9sZD0iMSIgZm9udC11bmRlcmxpbmU9IjAiIGZvbnQtYWxpZ25tZW50PSIxIiBzdHJva2VTdHlsZT0iMCIgbWFya2VyU3RhcnQ9IjAiIG1hcmtlckVuZD0iMCIgc2hhZG93RW5hYmxlZD0iMCIgc2hhZG93T2Zmc2V0WD0iMCIgc2hhZG93T2Zmc2V0WT0iMiIgc2hhZG93Qmx1cj0iNCIgc2hhZG93T3BhY2l0eT0iMTYwIiBibHVyRW5hYmxlZD0iMCIgYmx1clJhZGl1cz0iNCIgdHJhbnNmb3JtPSJtYXRyaXgoMSwwLDAsMSwzMTguOTM4LDI1Ni4yNzEpIiBwZXJzLWNlbnRlcj0iMCwwIiBwZXJzLXNpemU9IjAsMCIgcGVycy1zdGFydD0iMCwwIiBwZXJzLWVuZD0iMCwwIiBsb2NrZWQ9IjAiIG1lc2g9IiIgZmxhZz0iIi8+CiAgICAgICAgICAgIDxwYXRoIGlkPSJzaGFwZVBhdGgyIiBkPSJNMTc2LjI4NSwyNjkuMTczIEMxNzcuNTYxLDI3OC4zNzkgMTgwLjA2OCwyODUuMjYxIDE4My44MDUsMjg5LjgxOCBDMTkwLjY0MSwyOTguMTEyIDIwMi4zNTMsMzAyLjI1OSAyMTguOTQxLDMwMi4yNTkgQzIyOC44NzYsMzAyLjI1OSAyMzYuOTQzLDMwMS4xNjYgMjQzLjE0MSwyOTguOTc4IEMyNTQuODk4LDI5NC43ODUgMjYwLjc3NywyODYuOTkyIDI2MC43NzcsMjc1LjU5OSBDMjYwLjc3NywyNjguOTQ1IDI1Ny44NjEsMjYzLjc5NiAyNTIuMDI3LDI2MC4xNSBDMjQ2LjE5NCwyNTYuNTk1IDIzNy4wMzQsMjUzLjQ1MSAyMjQuNTQ3LDI1MC43MTYgTDIwMy4yMTksMjQ1LjkzMSBDMTgyLjI1NSwyNDEuMTkyIDE2Ny43NjMsMjM2LjA0MiAxNTkuNzQyLDIzMC40ODIgQzE0Ni4xNjEsMjIxLjE4NSAxMzkuMzcxLDIwNi42NDcgMTM5LjM3MSwxODYuODY5IEMxMzkuMzcxLDE2OC44MjIgMTQ1LjkzNCwxNTMuODI4IDE1OS4wNTksMTQxLjg4OCBDMTcyLjE4NCwxMjkuOTQ4IDE5MS40NjEsMTIzLjk3OCAyMTYuODkxLDEyMy45NzggQzIzOC4xMjgsMTIzLjk3OCAyNTYuMjQzLDEyOS42MDYgMjcxLjIzNiwxNDAuODYzIEMyODYuMjMsMTUyLjExOSAyOTQuMDkxLDE2OC40NTcgMjk0LjgyLDE4OS44NzYgTDI1NC4zNTIsMTg5Ljg3NiBDMjUzLjYyMiwxNzcuNzU0IDI0OC4zMzYsMTY5LjE0MSAyMzguNDkyLDE2NC4wMzcgQzIzMS45MywxNjAuNjY0IDIyMy43NzIsMTU4Ljk3OCAyMTQuMDIsMTU4Ljk3OCBDMjAzLjE3MywxNTguOTc4IDE5NC41MTQsMTYxLjE2NiAxODguMDQzLDE2NS41NDEgQzE4MS41NzIsMTY5LjkxNiAxNzguMzM2LDE3Ni4wMjIgMTc4LjMzNiwxODMuODYxIEMxNzguMzM2LDE5MS4wNjEgMTgxLjUyNiwxOTYuNDM5IDE4Ny45MDYsMTk5Ljk5NCBDMTkyLjAwOCwyMDIuMzYzIDIwMC43NTgsMjA1LjE0MyAyMTQuMTU2LDIwOC4zMzMgTDI0OC44ODMsMjE2LjY3MyBDMjY0LjEwNCwyMjAuMzE5IDI3NS41ODksMjI1LjE5NSAyODMuMzM2LDIzMS4zMDIgQzI5NS4zNjcsMjQwLjc4MSAzMDEuMzgzLDI1NC40OTkgMzAxLjM4MywyNzIuNDU1IEMzMDEuMzgzLDI5MC44NjYgMjk0LjM0MiwzMDYuMTU2IDI4MC4yNiwzMTguMzI0IEMyNjYuMTc4LDMzMC40OTIgMjQ2LjI4NSwzMzYuNTc2IDIyMC41ODIsMzM2LjU3NiBDMTk0LjMzMiwzMzYuNTc2IDE3My42ODgsMzMwLjU4MyAxNTguNjQ4LDMxOC41OTcgQzE0My42MDksMzA2LjYxMSAxMzYuMDksMjkwLjEzNyAxMzYuMDksMjY5LjE3MyBMMTc2LjI4NSwyNjkuMTczIE0zNzMuNDI2LDE2NC44NTcgTDM3My40MjYsMjk2LjM4IEw0MTIuMjU0LDI5Ni4zOCBDNDMyLjEyNCwyOTYuMzggNDQ1Ljk3OCwyODYuNTgyIDQ1My44MTYsMjY2Ljk4NiBDNDU4LjEsMjU2LjIzMSA0NjAuMjQyLDI0My40MjUgNDYwLjI0MiwyMjguNTY4IEM0NjAuMjQyLDIwOC4wNiA0NTcuMDI5LDE5Mi4zMTUgNDUwLjYwNCwxODEuMzMyIEM0NDQuMTc4LDE3MC4zNDggNDMxLjM5NSwxNjQuODU3IDQxMi4yNTQsMTY0Ljg1NyBMMzczLjQyNiwxNjQuODU3IE00MTkuMzYzLDEyOS44NTcgQzQzMS44NSwxMzAuMDM5IDQ0Mi4yNDEsMTMxLjQ5OCA0NTAuNTM1LDEzNC4yMzIgQzQ2NC42NjMsMTM4Ljg4IDQ3Ni4xMDIsMTQ3LjQwMiA0ODQuODUyLDE1OS43OTggQzQ5MS44NywxNjkuODI0IDQ5Ni42NTUsMTgwLjY3MSA0OTkuMjA3LDE5Mi4zMzcgQzUwMS43NTksMjA0LjAwNCA1MDMuMDM1LDIxNS4xMjQgNTAzLjAzNSwyMjUuNjk3IEM1MDMuMDM1LDI1Mi40OTQgNDk3LjY1OCwyNzUuMTg5IDQ4Ni45MDIsMjkzLjc4MyBDNDcyLjMxOSwzMTguODQ4IDQ0OS44MDYsMzMxLjM4IDQxOS4zNjMsMzMxLjM4IEwzMzIuNTQ3LDMzMS4zOCBMMzMyLjU0NywxMjkuODU3IEw0MTkuMzYzLDEyOS44NTcgWiIgc3R5bGU9InN0cm9rZTpub25lO2ZpbGwtcnVsZTpub256ZXJvO2ZpbGw6I2U2ZTZlNjtmaWxsLW9wYWNpdHk6MTsiLz4KICAgICAgICA8L2c+CiAgICA8L2c+Cjwvc3ZnPgo=";
	}
	elsif($format eq "HD"){
		$format = "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIj8+CjxzdmcgdmVyc2lvbj0iMS4xIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB3aWR0aD0iNjQwIiBoZWlnaHQ9IjQ4MCI+CiAgICA8ZGVzYyBpVmluY2k9InllcyIgdmVyc2lvbj0iNC42IiBncmlkU3RlcD0iMjAiIHNob3dHcmlkPSJubyIgc25hcFRvR3JpZD0ibm8iIGNvZGVQbGF0Zm9ybT0iMCIvPgogICAgPGcgaWQ9IkxheWVyMSIgbmFtZT0iTGF5ZXIgMSIgb3BhY2l0eT0iMSI+CiAgICAgICAgPGcgaWQ9IlNoYXBlMSI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjEiIHR5cGU9IjAiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjIiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMTY5LC0xMTYuNSwzMzgsMjMzKSIgdGV4dD0iIiBmb250LWZhbWlseU5hbWU9IkhlbHZldGljYSIgZm9udC1waXhlbFNpemU9IjIwIiBmb250LWJvbGQ9IjAiIGZvbnQtdW5kZXJsaW5lPSIwIiBmb250LWFsaWdubWVudD0iMSIgc3Ryb2tlU3R5bGU9IjAiIG1hcmtlclN0YXJ0PSIwIiBtYXJrZXJFbmQ9IjAiIHNoYWRvd0VuYWJsZWQ9IjAiIHNoYWRvd09mZnNldFg9IjAiIHNoYWRvd09mZnNldFk9IjIiIHNoYWRvd0JsdXI9IjQiIHNoYWRvd09wYWNpdHk9IjE2MCIgYmx1ckVuYWJsZWQ9IjAiIGJsdXJSYWRpdXM9IjQiIHRyYW5zZm9ybT0ibWF0cml4KDEuODkzNDksMCwwLDIuMDYwMDksMzIwLDI0MCkiIHBlcnMtY2VudGVyPSIwLDAiIHBlcnMtc2l6ZT0iMCwwIiBwZXJzLXN0YXJ0PSIwLDAiIHBlcnMtZW5kPSIwLDAiIGxvY2tlZD0iMCIgbWVzaD0iIiBmbGFnPSIiLz4KICAgICAgICAgICAgPHBhdGggaWQ9InNoYXBlUGF0aDEiIGQ9Ik0wLDI0LjcyMTEgQzAsMTEuMDY4OSAxMC4xNzM3LDEuNTI1ODhlLTA1IDIyLjcyMTksMS41MjU4OGUtMDUgTDYxNy4yNzgsMS41MjU4OGUtMDUgQzYyOS44MjYsMS41MjU4OGUtMDUgNjQwLDExLjA2ODkgNjQwLDI0LjcyMTEgTDY0MCw0NTUuMjc5IEM2NDAsNDY4LjkzMSA2MjkuODI2LDQ4MCA2MTcuMjc4LDQ4MCBMMjIuNzIxOSw0ODAgQzEwLjE3MzcsNDgwIDAsNDY4LjkzMSAwLDQ1NS4yNzkgTDAsMjQuNzIxMSBaIiBzdHlsZT0ic3Ryb2tlOiMzMjMyMzI7c3Ryb2tlLW9wYWNpdHk6MTtzdHJva2Utd2lkdGg6MTtzdHJva2UtbGluZWpvaW46bWl0ZXI7c3Ryb2tlLW1pdGVybGltaXQ6MjtzdHJva2UtbGluZWNhcDpyb3VuZDtmaWxsLXJ1bGU6ZXZlbm9kZDtmaWxsOiM5Njk2OTY7ZmlsbC1vcGFjaXR5OjE7Ii8+CiAgICAgICAgPC9nPgogICAgPC9nPgogICAgPGcgaWQ9IkxheWVyMiIgbmFtZT0iTGF5ZXIgMiIgb3BhY2l0eT0iMSI+CiAgICAgICAgPGcgaWQ9IlNoYXBlMiI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjIiIHR5cGU9IjIiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjAiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMzA2LjUsLTE5NC41LDYxMywzODkpIiB0ZXh0PSJIRCIgZm9udC1mYW1pbHlOYW1lPSJIZWx2ZXRpY2EiIGZvbnQtcGl4ZWxTaXplPSIyODAiIGZvbnQtYm9sZD0iMSIgZm9udC11bmRlcmxpbmU9IjAiIGZvbnQtYWxpZ25tZW50PSIxIiBzdHJva2VTdHlsZT0iMCIgbWFya2VyU3RhcnQ9IjAiIG1hcmtlckVuZD0iMCIgc2hhZG93RW5hYmxlZD0iMCIgc2hhZG93T2Zmc2V0WD0iMCIgc2hhZG93T2Zmc2V0WT0iMiIgc2hhZG93Qmx1cj0iNCIgc2hhZG93T3BhY2l0eT0iMTYwIiBibHVyRW5hYmxlZD0iMCIgYmx1clJhZGl1cz0iNCIgdHJhbnNmb3JtPSJtYXRyaXgoMSwwLDAsMSwzMTguOTM4LDI1Ni4yNzEpIiBwZXJzLWNlbnRlcj0iMCwwIiBwZXJzLXNpemU9IjAsMCIgcGVycy1zdGFydD0iMCwwIiBwZXJzLWVuZD0iMCwwIiBsb2NrZWQ9IjAiIG1lc2g9IiIgZmxhZz0iIi8+CiAgICAgICAgICAgIDxwYXRoIGlkPSJzaGFwZVBhdGgyIiBkPSJNMTM3Ljc4OSwzMzEuMzggTDEzNy43ODksMTI5Ljg1NyBMMTc5LjQ4OCwxMjkuODU3IEwxNzkuNDg4LDIwNi42OTMgTDI1OC4yMzgsMjA2LjY5MyBMMjU4LjIzOCwxMjkuODU3IEwzMDAuMDc0LDEyOS44NTcgTDMwMC4wNzQsMzMxLjM4IEwyNTguMjM4LDMzMS4zOCBMMjU4LjIzOCwyNDEuNDE5IEwxNzkuNDg4LDI0MS40MTkgTDE3OS40ODgsMzMxLjM4IEwxMzcuNzg5LDMzMS4zOCBNMzgxLjE0NSwxNjQuODU3IEwzODEuMTQ1LDI5Ni4zOCBMNDE5Ljk3MywyOTYuMzggQzQzOS44NDIsMjk2LjM4IDQ1My42OTcsMjg2LjU4MiA0NjEuNTM1LDI2Ni45ODYgQzQ2NS44MTksMjU2LjIzMSA0NjcuOTYxLDI0My40MjUgNDY3Ljk2MSwyMjguNTY4IEM0NjcuOTYxLDIwOC4wNiA0NjQuNzQ4LDE5Mi4zMTUgNDU4LjMyMiwxODEuMzMyIEM0NTEuODk2LDE3MC4zNDggNDM5LjExMywxNjQuODU3IDQxOS45NzMsMTY0Ljg1NyBMMzgxLjE0NSwxNjQuODU3IE00MjcuMDgyLDEyOS44NTcgQzQzOS41NjksMTMwLjAzOSA0NDkuOTYsMTMxLjQ5OCA0NTguMjU0LDEzNC4yMzIgQzQ3Mi4zODIsMTM4Ljg4IDQ4My44MiwxNDcuNDAyIDQ5Mi41NywxNTkuNzk4IEM0OTkuNTg5LDE2OS44MjQgNTA0LjM3NCwxODAuNjcxIDUwNi45MjYsMTkyLjMzNyBDNTA5LjQ3OCwyMDQuMDA0IDUxMC43NTQsMjE1LjEyNCA1MTAuNzU0LDIyNS42OTcgQzUxMC43NTQsMjUyLjQ5NCA1MDUuMzc2LDI3NS4xODkgNDk0LjYyMSwyOTMuNzgzIEM0ODAuMDM4LDMxOC44NDggNDU3LjUyNSwzMzEuMzggNDI3LjA4MiwzMzEuMzggTDM0MC4yNjYsMzMxLjM4IEwzNDAuMjY2LDEyOS44NTcgTDQyNy4wODIsMTI5Ljg1NyBaIiBzdHlsZT0ic3Ryb2tlOm5vbmU7ZmlsbC1ydWxlOm5vbnplcm87ZmlsbDojZTZlNmU2O2ZpbGwtb3BhY2l0eToxOyIvPgogICAgICAgIDwvZz4KICAgIDwvZz4KPC9zdmc+Cg==";
	}
	elsif($format eq "UHD"){
		$format = "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIj8+CjxzdmcgdmVyc2lvbj0iMS4xIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB3aWR0aD0iNjQwIiBoZWlnaHQ9IjQ4MCI+CiAgICA8ZGVzYyBpVmluY2k9InllcyIgdmVyc2lvbj0iNC42IiBncmlkU3RlcD0iMjAiIHNob3dHcmlkPSJubyIgc25hcFRvR3JpZD0ibm8iIGNvZGVQbGF0Zm9ybT0iMCIvPgogICAgPGcgaWQ9IkxheWVyMSIgbmFtZT0iTGF5ZXIgMSIgb3BhY2l0eT0iMSI+CiAgICAgICAgPGcgaWQ9IlNoYXBlMSI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjEiIHR5cGU9IjAiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjIiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMTY5LC0xMTYuNSwzMzgsMjMzKSIgdGV4dD0iIiBmb250LWZhbWlseU5hbWU9IkhlbHZldGljYSIgZm9udC1waXhlbFNpemU9IjIwIiBmb250LWJvbGQ9IjAiIGZvbnQtdW5kZXJsaW5lPSIwIiBmb250LWFsaWdubWVudD0iMSIgc3Ryb2tlU3R5bGU9IjAiIG1hcmtlclN0YXJ0PSIwIiBtYXJrZXJFbmQ9IjAiIHNoYWRvd0VuYWJsZWQ9IjAiIHNoYWRvd09mZnNldFg9IjAiIHNoYWRvd09mZnNldFk9IjIiIHNoYWRvd0JsdXI9IjQiIHNoYWRvd09wYWNpdHk9IjE2MCIgYmx1ckVuYWJsZWQ9IjAiIGJsdXJSYWRpdXM9IjQiIHRyYW5zZm9ybT0ibWF0cml4KDEuODkzNDksMCwwLDIuMDYwMDksMzIwLDI0MCkiIHBlcnMtY2VudGVyPSIwLDAiIHBlcnMtc2l6ZT0iMCwwIiBwZXJzLXN0YXJ0PSIwLDAiIHBlcnMtZW5kPSIwLDAiIGxvY2tlZD0iMCIgbWVzaD0iIiBmbGFnPSIiLz4KICAgICAgICAgICAgPHBhdGggaWQ9InNoYXBlUGF0aDEiIGQ9Ik0wLDI0LjcyMTEgQzAsMTEuMDY4OSAxMC4xNzM3LDEuNTI1ODhlLTA1IDIyLjcyMTksMS41MjU4OGUtMDUgTDYxNy4yNzgsMS41MjU4OGUtMDUgQzYyOS44MjYsMS41MjU4OGUtMDUgNjQwLDExLjA2ODkgNjQwLDI0LjcyMTEgTDY0MCw0NTUuMjc5IEM2NDAsNDY4LjkzMSA2MjkuODI2LDQ4MCA2MTcuMjc4LDQ4MCBMMjIuNzIxOSw0ODAgQzEwLjE3MzcsNDgwIDAsNDY4LjkzMSAwLDQ1NS4yNzkgTDAsMjQuNzIxMSBaIiBzdHlsZT0ic3Ryb2tlOiMzMjMyMzI7c3Ryb2tlLW9wYWNpdHk6MTtzdHJva2Utd2lkdGg6MTtzdHJva2UtbGluZWpvaW46bWl0ZXI7c3Ryb2tlLW1pdGVybGltaXQ6MjtzdHJva2UtbGluZWNhcDpyb3VuZDtmaWxsLXJ1bGU6ZXZlbm9kZDtmaWxsOiM5Njk2OTY7ZmlsbC1vcGFjaXR5OjE7Ii8+CiAgICAgICAgPC9nPgogICAgPC9nPgogICAgPGcgaWQ9IkxheWVyMiIgbmFtZT0iTGF5ZXIgMiIgb3BhY2l0eT0iMSI+CiAgICAgICAgPGcgaWQ9IlNoYXBlMiI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjIiIHR5cGU9IjIiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjAiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMzA2LjUsLTE5NC41LDYxMywzODkpIiB0ZXh0PSJVSEQiIGZvbnQtZmFtaWx5TmFtZT0iSGVsdmV0aWNhIiBmb250LXBpeGVsU2l6ZT0iMjgwIiBmb250LWJvbGQ9IjEiIGZvbnQtdW5kZXJsaW5lPSIwIiBmb250LWFsaWdubWVudD0iMSIgc3Ryb2tlU3R5bGU9IjAiIG1hcmtlclN0YXJ0PSIwIiBtYXJrZXJFbmQ9IjAiIHNoYWRvd0VuYWJsZWQ9IjAiIHNoYWRvd09mZnNldFg9IjAiIHNoYWRvd09mZnNldFk9IjIiIHNoYWRvd0JsdXI9IjQiIHNoYWRvd09wYWNpdHk9IjE2MCIgYmx1ckVuYWJsZWQ9IjAiIGJsdXJSYWRpdXM9IjQiIHRyYW5zZm9ybT0ibWF0cml4KDEsMCwwLDEsMzE4LjkzOCwyNTYuMjcxKSIgcGVycy1jZW50ZXI9IjAsMCIgcGVycy1zaXplPSIwLDAiIHBlcnMtc3RhcnQ9IjAsMCIgcGVycy1lbmQ9IjAsMCIgbG9ja2VkPSIwIiBtZXNoPSIiIGZsYWc9IiIvPgogICAgICAgICAgICA8cGF0aCBpZD0ic2hhcGVQYXRoMiIgZD0iTTM2Ljk2ODgsMTI5Ljg1NyBMNzkuNzYxNywxMjkuODU3IEw3OS43NjE3LDI1My43MjQgQzc5Ljc2MTcsMjY3LjU3OCA4MS40MDIzLDI3Ny42OTUgODQuNjgzNiwyODQuMDc2IEM4OS43ODc4LDI5NS4zNzggMTAwLjkwOCwzMDEuMDI5IDExOC4wNDMsMzAxLjAyOSBDMTM1LjA4NywzMDEuMDI5IDE0Ni4xNjEsMjk1LjM3OCAxNTEuMjY2LDI4NC4wNzYgQzE1NC41NDcsMjc3LjY5NSAxNTYuMTg4LDI2Ny41NzggMTU2LjE4OCwyNTMuNzI0IEwxNTYuMTg4LDEyOS44NTcgTDE5OC45OCwxMjkuODU3IEwxOTguOTgsMjUzLjcyNCBDMTk4Ljk4LDI3NS4xNDMgMTk1LjY1NCwyOTEuODIzIDE4OSwzMDMuNzYzIEMxNzYuNjA0LDMyNS42MzggMTUyLjk1MiwzMzYuNTc2IDExOC4wNDMsMzM2LjU3NiBDODMuMTM0MSwzMzYuNTc2IDU5LjQzNjIsMzI1LjYzOCA0Ni45NDkyLDMwMy43NjMgQzQwLjI5NTYsMjkxLjgyMyAzNi45Njg4LDI3NS4xNDMgMzYuOTY4OCwyNTMuNzI0IEwzNi45Njg4LDEyOS44NTcgTTIzOC44OTgsMzMxLjM4IEwyMzguODk4LDEyOS44NTcgTDI4MC41OTgsMTI5Ljg1NyBMMjgwLjU5OCwyMDYuNjkzIEwzNTkuMzQ4LDIwNi42OTMgTDM1OS4zNDgsMTI5Ljg1NyBMNDAxLjE4NCwxMjkuODU3IEw0MDEuMTg0LDMzMS4zOCBMMzU5LjM0OCwzMzEuMzggTDM1OS4zNDgsMjQxLjQxOSBMMjgwLjU5OCwyNDEuNDE5IEwyODAuNTk4LDMzMS4zOCBMMjM4Ljg5OCwzMzEuMzggTTQ4Mi4yNTQsMTY0Ljg1NyBMNDgyLjI1NCwyOTYuMzggTDUyMS4wODIsMjk2LjM4IEM1NDAuOTUyLDI5Ni4zOCA1NTQuODA2LDI4Ni41ODIgNTYyLjY0NSwyNjYuOTg2IEM1NjYuOTI4LDI1Ni4yMzEgNTY5LjA3LDI0My40MjUgNTY5LjA3LDIyOC41NjggQzU2OS4wNywyMDguMDYgNTY1Ljg1NywxOTIuMzE1IDU1OS40MzIsMTgxLjMzMiBDNTUzLjAwNiwxNzAuMzQ4IDU0MC4yMjMsMTY0Ljg1NyA1MjEuMDgyLDE2NC44NTcgTDQ4Mi4yNTQsMTY0Ljg1NyBNNTI4LjE5MSwxMjkuODU3IEM1NDAuNjc4LDEzMC4wMzkgNTUxLjA2OSwxMzEuNDk4IDU1OS4zNjMsMTM0LjIzMiBDNTczLjQ5MSwxMzguODggNTg0LjkzLDE0Ny40MDIgNTkzLjY4LDE1OS43OTggQzYwMC42OTgsMTY5LjgyNCA2MDUuNDgzLDE4MC42NzEgNjA4LjAzNSwxOTIuMzM3IEM2MTAuNTg3LDIwNC4wMDQgNjExLjg2MywyMTUuMTI0IDYxMS44NjMsMjI1LjY5NyBDNjExLjg2MywyNTIuNDk0IDYwNi40ODYsMjc1LjE4OSA1OTUuNzMsMjkzLjc4MyBDNTgxLjE0NywzMTguODQ4IDU1OC42MzQsMzMxLjM4IDUyOC4xOTEsMzMxLjM4IEw0NDEuMzc1LDMzMS4zOCBMNDQxLjM3NSwxMjkuODU3IEw1MjguMTkxLDEyOS44NTcgWiIgc3R5bGU9InN0cm9rZTpub25lO2ZpbGwtcnVsZTpub256ZXJvO2ZpbGw6I2U2ZTZlNjtmaWxsLW9wYWNpdHk6MTsiLz4KICAgICAgICA8L2c+CiAgICA8L2c+Cjwvc3ZnPgo=";
	}
	
	my $dolby 	= "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIj8+CjxzdmcgdmVyc2lvbj0iMS4xIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB3aWR0aD0iNjQwIiBoZWlnaHQ9IjQ4MCI+CiAgICA8ZGVzYyBpVmluY2k9InllcyIgdmVyc2lvbj0iNC42IiBncmlkU3RlcD0iMjAiIHNob3dHcmlkPSJubyIgc25hcFRvR3JpZD0ibm8iIGNvZGVQbGF0Zm9ybT0iMCIvPgogICAgPGcgaWQ9IkxheWVyMSIgbmFtZT0iTGF5ZXIgMSIgb3BhY2l0eT0iMSI+CiAgICAgICAgPGcgaWQ9IlNoYXBlMSI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjEiIHR5cGU9IjAiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjIiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMTY5LC0xMTYuNSwzMzgsMjMzKSIgdGV4dD0iIiBmb250LWZhbWlseU5hbWU9IkhlbHZldGljYSIgZm9udC1waXhlbFNpemU9IjIwIiBmb250LWJvbGQ9IjAiIGZvbnQtdW5kZXJsaW5lPSIwIiBmb250LWFsaWdubWVudD0iMSIgc3Ryb2tlU3R5bGU9IjAiIG1hcmtlclN0YXJ0PSIwIiBtYXJrZXJFbmQ9IjAiIHNoYWRvd0VuYWJsZWQ9IjAiIHNoYWRvd09mZnNldFg9IjAiIHNoYWRvd09mZnNldFk9IjIiIHNoYWRvd0JsdXI9IjQiIHNoYWRvd09wYWNpdHk9IjE2MCIgYmx1ckVuYWJsZWQ9IjAiIGJsdXJSYWRpdXM9IjQiIHRyYW5zZm9ybT0ibWF0cml4KDEuODkzNDksMCwwLDIuMDYwMDksMzIwLDI0MCkiIHBlcnMtY2VudGVyPSIwLDAiIHBlcnMtc2l6ZT0iMCwwIiBwZXJzLXN0YXJ0PSIwLDAiIHBlcnMtZW5kPSIwLDAiIGxvY2tlZD0iMCIgbWVzaD0iIiBmbGFnPSIiLz4KICAgICAgICAgICAgPHBhdGggaWQ9InNoYXBlUGF0aDEiIGQ9Ik0wLDI0LjcyMTEgQzAsMTEuMDY4OSAxMC4xNzM3LDEuNTI1ODhlLTA1IDIyLjcyMTksMS41MjU4OGUtMDUgTDYxNy4yNzgsMS41MjU4OGUtMDUgQzYyOS44MjYsMS41MjU4OGUtMDUgNjQwLDExLjA2ODkgNjQwLDI0LjcyMTEgTDY0MCw0NTUuMjc5IEM2NDAsNDY4LjkzMSA2MjkuODI2LDQ4MCA2MTcuMjc4LDQ4MCBMMjIuNzIxOSw0ODAgQzEwLjE3MzcsNDgwIDAsNDY4LjkzMSAwLDQ1NS4yNzkgTDAsMjQuNzIxMSBaIiBzdHlsZT0ic3Ryb2tlOiMzMjMyMzI7c3Ryb2tlLW9wYWNpdHk6MTtzdHJva2Utd2lkdGg6MTtzdHJva2UtbGluZWpvaW46bWl0ZXI7c3Ryb2tlLW1pdGVybGltaXQ6MjtzdHJva2UtbGluZWNhcDpyb3VuZDtmaWxsLXJ1bGU6ZXZlbm9kZDtmaWxsOiM5Njk2OTY7ZmlsbC1vcGFjaXR5OjE7Ii8+CiAgICAgICAgPC9nPgogICAgPC9nPgogICAgPGcgaWQ9IkxheWVyMiIgbmFtZT0iTGF5ZXIgMiIgb3BhY2l0eT0iMSI+CiAgICAgICAgPGcgaWQ9IlNoYXBlMiI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjIiIHR5cGU9IjIiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjAiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMTM0LjUsLTE2MiwyNjksMzI0KSIgdGV4dD0iRCIgZm9udC1mYW1pbHlOYW1lPSJIZWx2ZXRpY2EiIGZvbnQtcGl4ZWxTaXplPSI0NTAiIGZvbnQtYm9sZD0iMSIgZm9udC11bmRlcmxpbmU9IjAiIGZvbnQtYWxpZ25tZW50PSIxIiBzdHJva2VTdHlsZT0iMCIgbWFya2VyU3RhcnQ9IjAiIG1hcmtlckVuZD0iMCIgc2hhZG93RW5hYmxlZD0iMCIgc2hhZG93T2Zmc2V0WD0iMCIgc2hhZG93T2Zmc2V0WT0iMiIgc2hhZG93Qmx1cj0iNCIgc2hhZG93T3BhY2l0eT0iMTYwIiBibHVyRW5hYmxlZD0iMCIgYmx1clJhZGl1cz0iNCIgdHJhbnNmb3JtPSJtYXRyaXgoMSwwLDAsMSwxNjUuMDYyLDI3Ni45MzIpIiBwZXJzLWNlbnRlcj0iMCwwIiBwZXJzLXNpemU9IjAsMCIgcGVycy1zdGFydD0iMCwwIiBwZXJzLWVuZD0iMCwwIiBsb2NrZWQ9IjAiIG1lc2g9IiIgZmxhZz0iIi8+CiAgICAgICAgICAgIDxwYXRoIGlkPSJzaGFwZVBhdGgyIiBkPSJNMTAyLjU1NCwxMzAuODA1IEwxMDIuNTU0LDM0Mi4xODIgTDE2NC45NTYsMzQyLjE4MiBDMTk2Ljg5LDM0Mi4xODIgMjE5LjE1NSwzMjYuNDM1IDIzMS43NTMsMjk0Ljk0IEMyMzguNjM4LDI3Ny42NTUgMjQyLjA4LDI1Ny4wNzQgMjQyLjA4LDIzMy4xOTcgQzI0Mi4wOCwyMDAuMjM4IDIzNi45MTcsMTc0LjkzMyAyMjYuNTg5LDE1Ny4yODIgQzIxNi4yNjIsMTM5LjYzIDE5NS43MTgsMTMwLjgwNSAxNjQuOTU2LDEzMC44MDUgTDEwMi41NTQsMTMwLjgwNSBNMTc2LjM4Miw3NC41NTQ3IEMxOTYuNDUsNzQuODQ3NyAyMTMuMTQ5LDc3LjE5MTQgMjI2LjQ3OSw4MS41ODU5IEMyNDkuMTg1LDg5LjA1NjYgMjY3LjU2OCwxMDIuNzUzIDI4MS42MzEsMTIyLjY3NSBDMjkyLjkxLDEzOC43ODggMzAwLjYwMSwxNTYuMjIgMzA0LjcwMiwxNzQuOTcgQzMwOC44MDQsMTkzLjcyIDMxMC44NTQsMjExLjU5MSAzMTAuODU0LDIyOC41ODMgQzMxMC44NTQsMjcxLjY0OSAzMDIuMjEyLDMwOC4xMjQgMjg0LjkyNywzMzguMDA3IEMyNjEuNDg5LDM3OC4yOSAyMjUuMzA4LDM5OC40MzIgMTc2LjM4MiwzOTguNDMyIEwzNi44NTU1LDM5OC40MzIgTDM2Ljg1NTUsNzQuNTU0NyBMMTc2LjM4Miw3NC41NTQ3IFoiIHN0eWxlPSJzdHJva2U6bm9uZTtmaWxsLXJ1bGU6bm9uemVybztmaWxsOiNlNmU2ZTY7ZmlsbC1vcGFjaXR5OjE7Ii8+CiAgICAgICAgPC9nPgogICAgICAgIDxnIGlkPSJTaGFwZTMiPgogICAgICAgICAgICA8ZGVzYyBzaGFwZUlEPSIzIiB0eXBlPSIyIiBiYXNpY0luZm8tYmFzaWNUeXBlPSIwIiBiYXNpY0luZm8tcm91bmRlZFJlY3RSYWRpdXM9IjEyIiBiYXNpY0luZm8tcG9seWdvblNpZGVzPSI2IiBiYXNpY0luZm8tc3RhclBvaW50cz0iNSIgYm91bmRpbmc9InJlY3QoLTEzNC41LC0xNjIsMjY5LDMyNCkiIHRleHQ9IkQiIGZvbnQtZmFtaWx5TmFtZT0iSGVsdmV0aWNhIiBmb250LXBpeGVsU2l6ZT0iNDUwIiBmb250LWJvbGQ9IjEiIGZvbnQtdW5kZXJsaW5lPSIwIiBmb250LWFsaWdubWVudD0iMSIgc3Ryb2tlU3R5bGU9IjAiIG1hcmtlclN0YXJ0PSIwIiBtYXJrZXJFbmQ9IjAiIHNoYWRvd0VuYWJsZWQ9IjAiIHNoYWRvd09mZnNldFg9IjAiIHNoYWRvd09mZnNldFk9IjIiIHNoYWRvd0JsdXI9IjQiIHNoYWRvd09wYWNpdHk9IjE2MCIgYmx1ckVuYWJsZWQ9IjAiIGJsdXJSYWRpdXM9IjQiIHRyYW5zZm9ybT0ibWF0cml4KC0wLjk5OTk2NCwwLjAwODQ5OTY0LC0wLjAwODQ5OTY0LC0wLjk5OTk2NCw0NzcuMDYyLDIwMC4wNikiIHBlcnMtY2VudGVyPSIwLDAiIHBlcnMtc2l6ZT0iMCwwIiBwZXJzLXN0YXJ0PSIwLDAiIHBlcnMtZW5kPSIwLDAiIGxvY2tlZD0iMCIgbWVzaD0iIiBmbGFnPSIiLz4KICAgICAgICAgICAgPHBhdGggaWQ9InNoYXBlUGF0aDMiIGQ9Ik01NDAuODExLDM0NS42NSBMNTM5LjAxNCwxMzQuMjgxIEw0NzYuNjE0LDEzNC44MTEgQzQ0NC42ODIsMTM1LjA4MyA0MjIuNTUxLDE1MS4wMTggNDEwLjIyMSwxODIuNjE4IEM0MDMuNDg0LDE5OS45NjEgNDAwLjIxNiwyMjAuNTcxIDQwMC40MTksMjQ0LjQ0NyBDNDAwLjY5OSwyNzcuNDA1IDQwNi4wNzgsMzAyLjY2NSA0MTYuNTU1LDMyMC4yMjggQzQyNy4wMzIsMzM3Ljc5MSA0NDcuNjUsMzQ2LjQ0MiA0NzguNDExLDM0Ni4xODEgTDU0MC44MTEsMzQ1LjY1IE00NjcuNDY0LDQwMi41MjYgQzQ0Ny4zOTMsNDAyLjQwMyA0MzAuNjc1LDQwMC4yMDEgNDE3LjMwOCwzOTUuOTIgQzM5NC41NCwzODguNjQzIDM3Ni4wNDEsMzc1LjEwMyAzNjEuODA5LDM1NS4zMDIgQzM1MC4zOTQsMzM5LjI4NSAzNDIuNTU1LDMyMS45MTkgMzM4LjI5NCwzMDMuMjA1IEMzMzQuMDM0LDI4NC40OSAzMzEuODMxLDI2Ni42MzcgMzMxLjY4NywyNDkuNjQ2IEMzMzEuMzIxLDIwNi41ODEgMzM5LjY1MywxNzAuMDM0IDM1Ni42ODMsMTQwLjAwNiBDMzc5Ljc3OCw5OS41MjQ2IDQxNS43ODcsNzkuMDc2MiA0NjQuNzExLDc4LjY2MDMgTDYwNC4yMzIsNzcuNDc0NCBMNjA2Ljk4NSw0MDEuMzQgTDQ2Ny40NjQsNDAyLjUyNiBaIiBzdHlsZT0ic3Ryb2tlOm5vbmU7ZmlsbC1ydWxlOm5vbnplcm87ZmlsbDojZTZlNmU2O2ZpbGwtb3BhY2l0eToxOyIvPgogICAgICAgIDwvZz4KICAgICAgICA8ZyBpZD0iU2hhcGU0Ij4KICAgICAgICAgICAgPGRlc2Mgc2hhcGVJRD0iNCIgdHlwZT0iMCIgYmFzaWNJbmZvLWJhc2ljVHlwZT0iMSIgYmFzaWNJbmZvLXJvdW5kZWRSZWN0UmFkaXVzPSIxMiIgYmFzaWNJbmZvLXBvbHlnb25TaWRlcz0iNiIgYmFzaWNJbmZvLXN0YXJQb2ludHM9IjUiIGJvdW5kaW5nPSJyZWN0KC02OSwtMTA1LjUsMTM4LDIxMSkiIHRleHQ9IiIgZm9udC1mYW1pbHlOYW1lPSJIZWx2ZXRpY2EiIGZvbnQtcGl4ZWxTaXplPSI0MDAiIGZvbnQtYm9sZD0iMSIgZm9udC11bmRlcmxpbmU9IjAiIGZvbnQtYWxpZ25tZW50PSIxIiBzdHJva2VTdHlsZT0iMCIgbWFya2VyU3RhcnQ9IjAiIG1hcmtlckVuZD0iMCIgc2hhZG93RW5hYmxlZD0iMCIgc2hhZG93T2Zmc2V0WD0iMCIgc2hhZG93T2Zmc2V0WT0iMiIgc2hhZG93Qmx1cj0iNCIgc2hhZG93T3BhY2l0eT0iMTYwIiBibHVyRW5hYmxlZD0iMCIgYmx1clJhZGl1cz0iNCIgdHJhbnNmb3JtPSJtYXRyaXgoMS4yNjgxMiwwLDAsMS4xMjMyMiwxNjUsMjQ1KSIgcGVycy1jZW50ZXI9IjAsMCIgcGVycy1zaXplPSIwLDAiIHBlcnMtc3RhcnQ9IjAsMCIgcGVycy1lbmQ9IjAsMCIgbG9ja2VkPSIwIiBtZXNoPSIiIGZsYWc9IiIvPgogICAgICAgICAgICA8cGF0aCBpZD0ic2hhcGVQYXRoNCIgZD0iTTc3LjUsMTI2LjUgTDI1Mi41LDEyNi41IEwyNTIuNSwzNjMuNSBMNzcuNSwzNjMuNSBMNzcuNSwxMjYuNSBaIiBzdHlsZT0ic3Ryb2tlOm5vbmU7ZmlsbC1ydWxlOmV2ZW5vZGQ7ZmlsbDojZTZlNmU2O2ZpbGwtb3BhY2l0eToxOyIvPgogICAgICAgIDwvZz4KICAgICAgICA8ZyBpZD0iU2hhcGU1Ij4KICAgICAgICAgICAgPGRlc2Mgc2hhcGVJRD0iNSIgdHlwZT0iMCIgYmFzaWNJbmZvLWJhc2ljVHlwZT0iMSIgYmFzaWNJbmZvLXJvdW5kZWRSZWN0UmFkaXVzPSIxMiIgYmFzaWNJbmZvLXBvbHlnb25TaWRlcz0iNiIgYmFzaWNJbmZvLXN0YXJQb2ludHM9IjUiIGJvdW5kaW5nPSJyZWN0KC03NiwtMTA4LDE1MiwyMTYpIiB0ZXh0PSIiIGZvbnQtZmFtaWx5TmFtZT0iSGVsdmV0aWNhIiBmb250LXBpeGVsU2l6ZT0iNDAwIiBmb250LWJvbGQ9IjEiIGZvbnQtdW5kZXJsaW5lPSIwIiBmb250LWFsaWdubWVudD0iMSIgc3Ryb2tlU3R5bGU9IjAiIG1hcmtlclN0YXJ0PSIwIiBtYXJrZXJFbmQ9IjAiIHNoYWRvd0VuYWJsZWQ9IjAiIHNoYWRvd09mZnNldFg9IjAiIHNoYWRvd09mZnNldFk9IjIiIHNoYWRvd0JsdXI9IjQiIHNoYWRvd09wYWNpdHk9IjE2MCIgYmx1ckVuYWJsZWQ9IjAiIGJsdXJSYWRpdXM9IjQiIHRyYW5zZm9ybT0ibWF0cml4KDEuMjIzNjgsMCwwLDEuMDc0MDcsNDg3LjUsMjQyLjUpIiBwZXJzLWNlbnRlcj0iMCwwIiBwZXJzLXNpemU9IjAsMCIgcGVycy1zdGFydD0iMCwwIiBwZXJzLWVuZD0iMCwwIiBsb2NrZWQ9IjAiIG1lc2g9IiIgZmxhZz0iIi8+CiAgICAgICAgICAgIDxwYXRoIGlkPSJzaGFwZVBhdGg1IiBkPSJNMzk0LjUsMTI2LjUgTDU4MC41LDEyNi41IEw1ODAuNSwzNTguNSBMMzk0LjUsMzU4LjUgTDM5NC41LDEyNi41IFoiIHN0eWxlPSJzdHJva2U6bm9uZTtmaWxsLXJ1bGU6ZXZlbm9kZDtmaWxsOiNlNmU2ZTY7ZmlsbC1vcGFjaXR5OjE7Ii8+CiAgICAgICAgPC9nPgogICAgPC9nPgo8L3N2Zz4K";	
	my $ac3		= "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIj8+CjxzdmcgdmVyc2lvbj0iMS4xIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB3aWR0aD0iNjQwIiBoZWlnaHQ9IjQ4MCI+CiAgICA8ZGVzYyBpVmluY2k9InllcyIgdmVyc2lvbj0iNC42IiBncmlkU3RlcD0iMjAiIHNob3dHcmlkPSJubyIgc25hcFRvR3JpZD0ibm8iIGNvZGVQbGF0Zm9ybT0iMCIvPgogICAgPGcgaWQ9IkxheWVyMSIgbmFtZT0iTGF5ZXIgMSIgb3BhY2l0eT0iMSI+CiAgICAgICAgPGcgaWQ9IlNoYXBlMSI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjEiIHR5cGU9IjAiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjIiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMTY5LC0xMTYuNSwzMzgsMjMzKSIgdGV4dD0iIiBmb250LWZhbWlseU5hbWU9IkhlbHZldGljYSIgZm9udC1waXhlbFNpemU9IjIwIiBmb250LWJvbGQ9IjAiIGZvbnQtdW5kZXJsaW5lPSIwIiBmb250LWFsaWdubWVudD0iMSIgc3Ryb2tlU3R5bGU9IjAiIG1hcmtlclN0YXJ0PSIwIiBtYXJrZXJFbmQ9IjAiIHNoYWRvd0VuYWJsZWQ9IjAiIHNoYWRvd09mZnNldFg9IjAiIHNoYWRvd09mZnNldFk9IjIiIHNoYWRvd0JsdXI9IjQiIHNoYWRvd09wYWNpdHk9IjE2MCIgYmx1ckVuYWJsZWQ9IjAiIGJsdXJSYWRpdXM9IjQiIHRyYW5zZm9ybT0ibWF0cml4KDEuODkzNDksMCwwLDIuMDYwMDksMzIwLDI0MCkiIHBlcnMtY2VudGVyPSIwLDAiIHBlcnMtc2l6ZT0iMCwwIiBwZXJzLXN0YXJ0PSIwLDAiIHBlcnMtZW5kPSIwLDAiIGxvY2tlZD0iMCIgbWVzaD0iIiBmbGFnPSIiLz4KICAgICAgICAgICAgPHBhdGggaWQ9InNoYXBlUGF0aDEiIGQ9Ik0wLDI0LjcyMTEgQzAsMTEuMDY4OSAxMC4xNzM3LDEuNTI1ODhlLTA1IDIyLjcyMTksMS41MjU4OGUtMDUgTDYxNy4yNzgsMS41MjU4OGUtMDUgQzYyOS44MjYsMS41MjU4OGUtMDUgNjQwLDExLjA2ODkgNjQwLDI0LjcyMTEgTDY0MCw0NTUuMjc5IEM2NDAsNDY4LjkzMSA2MjkuODI2LDQ4MCA2MTcuMjc4LDQ4MCBMMjIuNzIxOSw0ODAgQzEwLjE3MzcsNDgwIDAsNDY4LjkzMSAwLDQ1NS4yNzkgTDAsMjQuNzIxMSBaIiBzdHlsZT0ic3Ryb2tlOiMzMjMyMzI7c3Ryb2tlLW9wYWNpdHk6MTtzdHJva2Utd2lkdGg6MTtzdHJva2UtbGluZWpvaW46bWl0ZXI7c3Ryb2tlLW1pdGVybGltaXQ6MjtzdHJva2UtbGluZWNhcDpyb3VuZDtmaWxsLXJ1bGU6ZXZlbm9kZDtmaWxsOiM5Njk2OTY7ZmlsbC1vcGFjaXR5OjE7Ii8+CiAgICAgICAgPC9nPgogICAgPC9nPgogICAgPGcgaWQ9IkxheWVyMiIgbmFtZT0iTGF5ZXIgMyIgb3BhY2l0eT0iMSI+CiAgICAgICAgPGcgaWQ9IlNoYXBlMiI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjIiIHR5cGU9IjAiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjQiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMTI4LjUsLTEyNywyNTcsMjU0KSIgdGV4dD0iIiBmb250LWZhbWlseU5hbWU9IkhlbHZldGljYSIgZm9udC1waXhlbFNpemU9IjI4MCIgZm9udC1ib2xkPSIxIiBmb250LXVuZGVybGluZT0iMCIgZm9udC1hbGlnbm1lbnQ9IjEiIHN0cm9rZVN0eWxlPSIwIiBtYXJrZXJTdGFydD0iMCIgbWFya2VyRW5kPSIwIiBzaGFkb3dFbmFibGVkPSIwIiBzaGFkb3dPZmZzZXRYPSIwIiBzaGFkb3dPZmZzZXRZPSIyIiBzaGFkb3dCbHVyPSI0IiBzaGFkb3dPcGFjaXR5PSIxNjAiIGJsdXJFbmFibGVkPSIwIiBibHVyUmFkaXVzPSI0IiB0cmFuc2Zvcm09Im1hdHJpeCgwLjU3MTk4NCwwLDAsMC41NTkwNTUsMzIwLDk5LjAwMDEpIiBwZXJzLWNlbnRlcj0iMCwwIiBwZXJzLXNpemU9IjAsMCIgcGVycy1zdGFydD0iMCwwIiBwZXJzLWVuZD0iMCwwIiBsb2NrZWQ9IjAiIG1lc2g9IiIgZmxhZz0iIi8+CiAgICAgICAgICAgIDxwYXRoIGlkPSJzaGFwZVBhdGgyIiBkPSJNMjQ2LjUsOTkuMDAwMSBDMjQ2LjUsNTkuNzg3OSAyNzkuNDA3LDI4LjAwMDEgMzIwLDI4LjAwMDEgQzM2MC41OTMsMjguMDAwMSAzOTMuNSw1OS43ODc5IDM5My41LDk5LjAwMDEgQzM5My41LDEzOC4yMTIgMzYwLjU5MywxNzAgMzIwLDE3MCBDMjc5LjQwNywxNzAgMjQ2LjUsMTM4LjIxMiAyNDYuNSw5OS4wMDAxIFoiIHN0eWxlPSJzdHJva2U6I2U2ZTZlNjtzdHJva2Utb3BhY2l0eToxO3N0cm9rZS13aWR0aDoyMDtzdHJva2UtbGluZWpvaW46bWl0ZXI7c3Ryb2tlLW1pdGVybGltaXQ6MjtzdHJva2UtbGluZWNhcDpyb3VuZDtmaWxsOm5vbmU7Ii8+CiAgICAgICAgPC9nPgogICAgICAgIDxnIGlkPSJTaGFwZTMiPgogICAgICAgICAgICA8ZGVzYyBzaGFwZUlEPSIzIiB0eXBlPSIwIiBiYXNpY0luZm8tYmFzaWNUeXBlPSI0IiBiYXNpY0luZm8tcm91bmRlZFJlY3RSYWRpdXM9IjEyIiBiYXNpY0luZm8tcG9seWdvblNpZGVzPSI2IiBiYXNpY0luZm8tc3RhclBvaW50cz0iNSIgYm91bmRpbmc9InJlY3QoLTEyOC41LC0xMjcsMjU3LDI1NCkiIHRleHQ9IiIgZm9udC1mYW1pbHlOYW1lPSJIZWx2ZXRpY2EiIGZvbnQtcGl4ZWxTaXplPSIyODAiIGZvbnQtYm9sZD0iMSIgZm9udC11bmRlcmxpbmU9IjAiIGZvbnQtYWxpZ25tZW50PSIxIiBzdHJva2VTdHlsZT0iMCIgbWFya2VyU3RhcnQ9IjAiIG1hcmtlckVuZD0iMCIgc2hhZG93RW5hYmxlZD0iMCIgc2hhZG93T2Zmc2V0WD0iMCIgc2hhZG93T2Zmc2V0WT0iMiIgc2hhZG93Qmx1cj0iNCIgc2hhZG93T3BhY2l0eT0iMTYwIiBibHVyRW5hYmxlZD0iMCIgYmx1clJhZGl1cz0iNCIgdHJhbnNmb3JtPSJtYXRyaXgoMC41NzE5ODQsMCwwLDAuNTU5MDU1LDUyNiwxMDgpIiBwZXJzLWNlbnRlcj0iMCwwIiBwZXJzLXNpemU9IjAsMCIgcGVycy1zdGFydD0iMCwwIiBwZXJzLWVuZD0iMCwwIiBsb2NrZWQ9IjAiIG1lc2g9IiIgZmxhZz0iIi8+CiAgICAgICAgICAgIDxwYXRoIGlkPSJzaGFwZVBhdGgzIiBkPSJNNDUyLjUsMTA4IEM0NTIuNSw2OC43ODc5IDQ4NS40MDcsMzcuMDAwMSA1MjYsMzcuMDAwMSBDNTY2LjU5MywzNy4wMDAxIDU5OS41LDY4Ljc4NzkgNTk5LjUsMTA4IEM1OTkuNSwxNDcuMjEyIDU2Ni41OTMsMTc5IDUyNiwxNzkgQzQ4NS40MDcsMTc5IDQ1Mi41LDE0Ny4yMTIgNDUyLjUsMTA4IFoiIHN0eWxlPSJzdHJva2U6I2U2ZTZlNjtzdHJva2Utb3BhY2l0eToxO3N0cm9rZS13aWR0aDoyMDtzdHJva2UtbGluZWpvaW46bWl0ZXI7c3Ryb2tlLW1pdGVybGltaXQ6MjtzdHJva2UtbGluZWNhcDpyb3VuZDtmaWxsOm5vbmU7Ii8+CiAgICAgICAgPC9nPgogICAgICAgIDxnIGlkPSJTaGFwZTQiPgogICAgICAgICAgICA8ZGVzYyBzaGFwZUlEPSI0IiB0eXBlPSIwIiBiYXNpY0luZm8tYmFzaWNUeXBlPSI0IiBiYXNpY0luZm8tcm91bmRlZFJlY3RSYWRpdXM9IjEyIiBiYXNpY0luZm8tcG9seWdvblNpZGVzPSI2IiBiYXNpY0luZm8tc3RhclBvaW50cz0iNSIgYm91bmRpbmc9InJlY3QoLTEyOC41LC0xMjcsMjU3LDI1NCkiIHRleHQ9IiIgZm9udC1mYW1pbHlOYW1lPSJIZWx2ZXRpY2EiIGZvbnQtcGl4ZWxTaXplPSIyODAiIGZvbnQtYm9sZD0iMSIgZm9udC11bmRlcmxpbmU9IjAiIGZvbnQtYWxpZ25tZW50PSIxIiBzdHJva2VTdHlsZT0iMCIgbWFya2VyU3RhcnQ9IjAiIG1hcmtlckVuZD0iMCIgc2hhZG93RW5hYmxlZD0iMCIgc2hhZG93T2Zmc2V0WD0iMCIgc2hhZG93T2Zmc2V0WT0iMiIgc2hhZG93Qmx1cj0iNCIgc2hhZG93T3BhY2l0eT0iMTYwIiBibHVyRW5hYmxlZD0iMCIgYmx1clJhZGl1cz0iNCIgdHJhbnNmb3JtPSJtYXRyaXgoMC41NzE5ODQsMCwwLDAuNTU5MDU1LDExMywxMDgpIiBwZXJzLWNlbnRlcj0iMCwwIiBwZXJzLXNpemU9IjAsMCIgcGVycy1zdGFydD0iMCwwIiBwZXJzLWVuZD0iMCwwIiBsb2NrZWQ9IjAiIG1lc2g9IiIgZmxhZz0iIi8+CiAgICAgICAgICAgIDxwYXRoIGlkPSJzaGFwZVBhdGg0IiBkPSJNMzkuNSwxMDggQzM5LjUsNjguNzg3OSA3Mi40MDcxLDM3LjAwMDEgMTEzLDM3LjAwMDEgQzE1My41OTMsMzcuMDAwMSAxODYuNSw2OC43ODc5IDE4Ni41LDEwOCBDMTg2LjUsMTQ3LjIxMiAxNTMuNTkzLDE3OSAxMTMsMTc5IEM3Mi40MDcxLDE3OSAzOS41LDE0Ny4yMTIgMzkuNSwxMDggWiIgc3R5bGU9InN0cm9rZTojZTZlNmU2O3N0cm9rZS1vcGFjaXR5OjE7c3Ryb2tlLXdpZHRoOjIwO3N0cm9rZS1saW5lam9pbjptaXRlcjtzdHJva2UtbWl0ZXJsaW1pdDoyO3N0cm9rZS1saW5lY2FwOnJvdW5kO2ZpbGw6bm9uZTsiLz4KICAgICAgICA8L2c+CiAgICAgICAgPGcgaWQ9IlNoYXBlNSI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjUiIHR5cGU9IjAiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjQiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMTI4LjUsLTEyNywyNTcsMjU0KSIgdGV4dD0iIiBmb250LWZhbWlseU5hbWU9IkhlbHZldGljYSIgZm9udC1waXhlbFNpemU9IjI4MCIgZm9udC1ib2xkPSIxIiBmb250LXVuZGVybGluZT0iMCIgZm9udC1hbGlnbm1lbnQ9IjEiIHN0cm9rZVN0eWxlPSIwIiBtYXJrZXJTdGFydD0iMCIgbWFya2VyRW5kPSIwIiBzaGFkb3dFbmFibGVkPSIwIiBzaGFkb3dPZmZzZXRYPSIwIiBzaGFkb3dPZmZzZXRZPSIyIiBzaGFkb3dCbHVyPSI0IiBzaGFkb3dPcGFjaXR5PSIxNjAiIGJsdXJFbmFibGVkPSIwIiBibHVyUmFkaXVzPSI0IiB0cmFuc2Zvcm09Im1hdHJpeCgwLjU3MTk4NCwwLDAsMC41NTkwNTUsNTI2LDM3MSkiIHBlcnMtY2VudGVyPSIwLDAiIHBlcnMtc2l6ZT0iMCwwIiBwZXJzLXN0YXJ0PSIwLDAiIHBlcnMtZW5kPSIwLDAiIGxvY2tlZD0iMCIgbWVzaD0iIiBmbGFnPSIiLz4KICAgICAgICAgICAgPHBhdGggaWQ9InNoYXBlUGF0aDUiIGQ9Ik00NTIuNSwzNzEgQzQ1Mi41LDMzMS43ODggNDg1LjQwNywzMDAgNTI2LDMwMCBDNTY2LjU5MywzMDAgNTk5LjUsMzMxLjc4OCA1OTkuNSwzNzEgQzU5OS41LDQxMC4yMTIgNTY2LjU5Myw0NDIgNTI2LDQ0MiBDNDg1LjQwNyw0NDIgNDUyLjUsNDEwLjIxMiA0NTIuNSwzNzEgWiIgc3R5bGU9InN0cm9rZTojZTZlNmU2O3N0cm9rZS1vcGFjaXR5OjE7c3Ryb2tlLXdpZHRoOjIwO3N0cm9rZS1saW5lam9pbjptaXRlcjtzdHJva2UtbWl0ZXJsaW1pdDoyO3N0cm9rZS1saW5lY2FwOnJvdW5kO2ZpbGw6bm9uZTsiLz4KICAgICAgICA8L2c+CiAgICAgICAgPGcgaWQ9IlNoYXBlNiI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjYiIHR5cGU9IjAiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjQiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMTI4LjUsLTEyNywyNTcsMjU0KSIgdGV4dD0iIiBmb250LWZhbWlseU5hbWU9IkhlbHZldGljYSIgZm9udC1waXhlbFNpemU9IjI4MCIgZm9udC1ib2xkPSIxIiBmb250LXVuZGVybGluZT0iMCIgZm9udC1hbGlnbm1lbnQ9IjEiIHN0cm9rZVN0eWxlPSIwIiBtYXJrZXJTdGFydD0iMCIgbWFya2VyRW5kPSIwIiBzaGFkb3dFbmFibGVkPSIwIiBzaGFkb3dPZmZzZXRYPSIwIiBzaGFkb3dPZmZzZXRZPSIyIiBzaGFkb3dCbHVyPSI0IiBzaGFkb3dPcGFjaXR5PSIxNjAiIGJsdXJFbmFibGVkPSIwIiBibHVyUmFkaXVzPSI0IiB0cmFuc2Zvcm09Im1hdHJpeCgwLjU3MTk4NCwwLDAsMC41NTkwNTUsMTEzLDM3MSkiIHBlcnMtY2VudGVyPSIwLDAiIHBlcnMtc2l6ZT0iMCwwIiBwZXJzLXN0YXJ0PSIwLDAiIHBlcnMtZW5kPSIwLDAiIGxvY2tlZD0iMCIgbWVzaD0iIiBmbGFnPSIiLz4KICAgICAgICAgICAgPHBhdGggaWQ9InNoYXBlUGF0aDYiIGQ9Ik0zOS41LDM3MSBDMzkuNSwzMzEuNzg4IDcyLjQwNzEsMzAwIDExMywzMDAgQzE1My41OTMsMzAwIDE4Ni41LDMzMS43ODggMTg2LjUsMzcxIEMxODYuNSw0MTAuMjEyIDE1My41OTMsNDQyIDExMyw0NDIgQzcyLjQwNzEsNDQyIDM5LjUsNDEwLjIxMiAzOS41LDM3MSBaIiBzdHlsZT0ic3Ryb2tlOiNlNmU2ZTY7c3Ryb2tlLW9wYWNpdHk6MTtzdHJva2Utd2lkdGg6MjA7c3Ryb2tlLWxpbmVqb2luOm1pdGVyO3N0cm9rZS1taXRlcmxpbWl0OjI7c3Ryb2tlLWxpbmVjYXA6cm91bmQ7ZmlsbDpub25lOyIvPgogICAgICAgIDwvZz4KICAgIDwvZz4KPC9zdmc+Cg==";
	my $stereo	= "data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIj8+CjxzdmcgdmVyc2lvbj0iMS4xIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB3aWR0aD0iNjQwIiBoZWlnaHQ9IjQ4MCI+CiAgICA8ZGVzYyBpVmluY2k9InllcyIgdmVyc2lvbj0iNC42IiBncmlkU3RlcD0iMjAiIHNob3dHcmlkPSJubyIgc25hcFRvR3JpZD0ibm8iIGNvZGVQbGF0Zm9ybT0iMCIvPgogICAgPGcgaWQ9IkxheWVyMSIgbmFtZT0iTGF5ZXIgMSIgb3BhY2l0eT0iMSI+CiAgICAgICAgPGcgaWQ9IlNoYXBlMSI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjEiIHR5cGU9IjAiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjIiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMTY5LC0xMTYuNSwzMzgsMjMzKSIgdGV4dD0iIiBmb250LWZhbWlseU5hbWU9IkhlbHZldGljYSIgZm9udC1waXhlbFNpemU9IjIwIiBmb250LWJvbGQ9IjAiIGZvbnQtdW5kZXJsaW5lPSIwIiBmb250LWFsaWdubWVudD0iMSIgc3Ryb2tlU3R5bGU9IjAiIG1hcmtlclN0YXJ0PSIwIiBtYXJrZXJFbmQ9IjAiIHNoYWRvd0VuYWJsZWQ9IjAiIHNoYWRvd09mZnNldFg9IjAiIHNoYWRvd09mZnNldFk9IjIiIHNoYWRvd0JsdXI9IjQiIHNoYWRvd09wYWNpdHk9IjE2MCIgYmx1ckVuYWJsZWQ9IjAiIGJsdXJSYWRpdXM9IjQiIHRyYW5zZm9ybT0ibWF0cml4KDEuODkzNDksMCwwLDIuMDYwMDksMzIwLDI0MCkiIHBlcnMtY2VudGVyPSIwLDAiIHBlcnMtc2l6ZT0iMCwwIiBwZXJzLXN0YXJ0PSIwLDAiIHBlcnMtZW5kPSIwLDAiIGxvY2tlZD0iMCIgbWVzaD0iIiBmbGFnPSIiLz4KICAgICAgICAgICAgPHBhdGggaWQ9InNoYXBlUGF0aDEiIGQ9Ik0wLDI0LjcyMTEgQzAsMTEuMDY4OSAxMC4xNzM3LDEuNTI1ODhlLTA1IDIyLjcyMTksMS41MjU4OGUtMDUgTDYxNy4yNzgsMS41MjU4OGUtMDUgQzYyOS44MjYsMS41MjU4OGUtMDUgNjQwLDExLjA2ODkgNjQwLDI0LjcyMTEgTDY0MCw0NTUuMjc5IEM2NDAsNDY4LjkzMSA2MjkuODI2LDQ4MCA2MTcuMjc4LDQ4MCBMMjIuNzIxOSw0ODAgQzEwLjE3MzcsNDgwIDAsNDY4LjkzMSAwLDQ1NS4yNzkgTDAsMjQuNzIxMSBaIiBzdHlsZT0ic3Ryb2tlOiMzMjMyMzI7c3Ryb2tlLW9wYWNpdHk6MTtzdHJva2Utd2lkdGg6MTtzdHJva2UtbGluZWpvaW46bWl0ZXI7c3Ryb2tlLW1pdGVybGltaXQ6MjtzdHJva2UtbGluZWNhcDpyb3VuZDtmaWxsLXJ1bGU6ZXZlbm9kZDtmaWxsOiM5Njk2OTY7ZmlsbC1vcGFjaXR5OjE7Ii8+CiAgICAgICAgPC9nPgogICAgPC9nPgogICAgPGcgaWQ9IkxheWVyMiIgbmFtZT0iTGF5ZXIgMyIgb3BhY2l0eT0iMSI+CiAgICAgICAgPGcgaWQ9IlNoYXBlMiI+CiAgICAgICAgICAgIDxkZXNjIHNoYXBlSUQ9IjIiIHR5cGU9IjAiIGJhc2ljSW5mby1iYXNpY1R5cGU9IjQiIGJhc2ljSW5mby1yb3VuZGVkUmVjdFJhZGl1cz0iMTIiIGJhc2ljSW5mby1wb2x5Z29uU2lkZXM9IjYiIGJhc2ljSW5mby1zdGFyUG9pbnRzPSI1IiBib3VuZGluZz0icmVjdCgtMTI4LjUsLTEyNywyNTcsMjU0KSIgdGV4dD0iIiBmb250LWZhbWlseU5hbWU9IkhlbHZldGljYSIgZm9udC1waXhlbFNpemU9IjI4MCIgZm9udC1ib2xkPSIxIiBmb250LXVuZGVybGluZT0iMCIgZm9udC1hbGlnbm1lbnQ9IjEiIHN0cm9rZVN0eWxlPSIwIiBtYXJrZXJTdGFydD0iMCIgbWFya2VyRW5kPSIwIiBzaGFkb3dFbmFibGVkPSIwIiBzaGFkb3dPZmZzZXRYPSIwIiBzaGFkb3dPZmZzZXRZPSIyIiBzaGFkb3dCbHVyPSI0IiBzaGFkb3dPcGFjaXR5PSIxNjAiIGJsdXJFbmFibGVkPSIwIiBibHVyUmFkaXVzPSI0IiB0cmFuc2Zvcm09Im1hdHJpeCgxLDAsMCwxLDE3MCwyNDApIiBwZXJzLWNlbnRlcj0iMCwwIiBwZXJzLXNpemU9IjAsMCIgcGVycy1zdGFydD0iMCwwIiBwZXJzLWVuZD0iMCwwIiBsb2NrZWQ9IjAiIG1lc2g9IiIgZmxhZz0iIi8+CiAgICAgICAgICAgIDxwYXRoIGlkPSJzaGFwZVBhdGgyIiBkPSJNNDEuNSwyNDAgQzQxLjUsMTY5Ljg2IDk5LjAzMTQsMTEzIDE3MCwxMTMgQzI0MC45NjksMTEzIDI5OC41LDE2OS44NiAyOTguNSwyNDAgQzI5OC41LDMxMC4xNCAyNDAuOTY5LDM2NyAxNzAsMzY3IEM5OS4wMzE0LDM2NyA0MS41LDMxMC4xNCA0MS41LDI0MCBaIiBzdHlsZT0ic3Ryb2tlOiNlNmU2ZTY7c3Ryb2tlLW9wYWNpdHk6MTtzdHJva2Utd2lkdGg6NDA7c3Ryb2tlLWxpbmVqb2luOm1pdGVyO3N0cm9rZS1taXRlcmxpbWl0OjI7c3Ryb2tlLWxpbmVjYXA6cm91bmQ7ZmlsbDpub25lOyIvPgogICAgICAgIDwvZz4KICAgICAgICA8ZyBpZD0iU2hhcGUzIj4KICAgICAgICAgICAgPGRlc2Mgc2hhcGVJRD0iMyIgdHlwZT0iMCIgYmFzaWNJbmZvLWJhc2ljVHlwZT0iNCIgYmFzaWNJbmZvLXJvdW5kZWRSZWN0UmFkaXVzPSIxMiIgYmFzaWNJbmZvLXBvbHlnb25TaWRlcz0iNiIgYmFzaWNJbmZvLXN0YXJQb2ludHM9IjUiIGJvdW5kaW5nPSJyZWN0KC0xMjguNSwtMTI3LDI1NywyNTQpIiB0ZXh0PSIiIGZvbnQtZmFtaWx5TmFtZT0iSGVsdmV0aWNhIiBmb250LXBpeGVsU2l6ZT0iMjgwIiBmb250LWJvbGQ9IjEiIGZvbnQtdW5kZXJsaW5lPSIwIiBmb250LWFsaWdubWVudD0iMSIgc3Ryb2tlU3R5bGU9IjAiIG1hcmtlclN0YXJ0PSIwIiBtYXJrZXJFbmQ9IjAiIHNoYWRvd0VuYWJsZWQ9IjAiIHNoYWRvd09mZnNldFg9IjAiIHNoYWRvd09mZnNldFk9IjIiIHNoYWRvd0JsdXI9IjQiIHNoYWRvd09wYWNpdHk9IjE2MCIgYmx1ckVuYWJsZWQ9IjAiIGJsdXJSYWRpdXM9IjQiIHRyYW5zZm9ybT0ibWF0cml4KDEsMCwwLDEsNDc4LDI0MCkiIHBlcnMtY2VudGVyPSIwLDAiIHBlcnMtc2l6ZT0iMCwwIiBwZXJzLXN0YXJ0PSIwLDAiIHBlcnMtZW5kPSIwLDAiIGxvY2tlZD0iMCIgbWVzaD0iIiBmbGFnPSIiLz4KICAgICAgICAgICAgPHBhdGggaWQ9InNoYXBlUGF0aDMiIGQ9Ik0zNDkuNSwyNDAgQzM0OS41LDE2OS44NiA0MDcuMDMxLDExMyA0NzgsMTEzIEM1NDguOTY5LDExMyA2MDYuNSwxNjkuODYgNjA2LjUsMjQwIEM2MDYuNSwzMTAuMTQgNTQ4Ljk2OSwzNjcgNDc4LDM2NyBDNDA3LjAzMSwzNjcgMzQ5LjUsMzEwLjE0IDM0OS41LDI0MCBaIiBzdHlsZT0ic3Ryb2tlOiNlNmU2ZTY7c3Ryb2tlLW9wYWNpdHk6MTtzdHJva2Utd2lkdGg6NDA7c3Ryb2tlLWxpbmVqb2luOm1pdGVyO3N0cm9rZS1taXRlcmxpbWl0OjI7c3Ryb2tlLWxpbmVjYXA6cm91bmQ7ZmlsbDpub25lOyIvPgogICAgICAgIDwvZz4KICAgIDwvZz4KPC9zdmc+Cg==";
	
	
	if(defined($mix)){
		if($mix eq "stereo"){
			if(defined($coding)){
				if($coding eq "ac3"){
					$audio = 	'<td valign="top" style="padding: 0px; margin: 0px;"><div style="display: inline-block; margin-left: 5px;"><img src="'.$dolby.'" width="22" height="22"></div></td>';
					$audio .= 	'<td valign="top" style="padding: 0px; margin: 0px;"><div style="display: inline-block; margin-left: 5px;"><img src="'.$stereo.'" width="22" height="22"></div></td>';
				}
			}
			else{
					$audio = 	'<td valign="top" style="padding: 0px; margin: 0px;"><div style="margin-left: 5px;"><img src="'.$stereo.'" width="22" height="22"></div></td>';
			}
		}
		elsif($mix eq "surround"){
			if(defined($coding)){
				if($coding eq "ac3"){
					$audio = 	'<td valign="top" style="padding: 0px; margin: 0px;"><div style="display: inline-block; margin-left: 5px;"><img src="'.$dolby.'" width="22" height="22"></div></td>';
					$audio .= 	'<td valign="top" style="padding: 0px; margin: 0px;"><div style="display: inline-block; margin-left: 5px;"><img src="'.$ac3.'" width="22" height="22">';
				}
			}
		}
	}
	
	if($on){
		$html .= '<div style="padding: 0px; margin: 0px;">'; 
		$html .= '<table cellpadding="0" cellspacing="0" style="text-align: center; padding: 0px 0px; margin: 0px 0px;">
						<tr>
							<td valign="top" style="padding: 0px; margin: 0px;">
								<div style="display: inline-block;" ><img src="'.$format.'" width="22" height="22"></div>
							</td>
							'.$audio.'
						</tr>
					</table>';
		$html .= '</div>';
	}	
			
	$html =~ s/\n/ /g;
	
	return $html;
}

sub MagentaTV_summaryFn {
	my ($FW_wname, $hash, $room, $pageHash) = @_;
    $hash            = $defs{$hash};
    my $state        = $hash->{STATE};
    my $name         = $hash->{NAME};

    Log3 $name, 5, $name.": <summaryFn> start ";
    
    return; # erst mal ausschalten
}

################################################################################
# ACCOUNT ######################################################################
################################################################################

# HTTP Request #################################################################

sub MagentaTV_getHTTPRequest {
    my ($hash, $url, $postData, $xml, $cookie, $csrfToken, $hideurl) = @_;
    my $name = $hash->{NAME};
    
    Log3 $name, 5, $name.": <getHTTPRequest> start";
    
    my $header = {
					"Content-Type" 		=> "application/x-www-form-urlencoded; charset=UTF-8",
					"Accept" 			=> "application/json, text/javascript, */*; q=0.01",
					"Accept-Language" 	=> "en-US,en;q=0.9,de;q=0.8", #"de-de",
					"Accept-Encoding"	=> "br, gzip, deflate",
			 	 	"User-Agent" 		=> USER_AGENT,
			 	 	"Connection"		=> "keep-alive"		 	 	
			 	 };
	if(defined($cookie)){
		$header->{"Cookie"} = $cookie;
	}
	if(defined($xml)){
		$header->{"X-Requested-With"} = "XMLHttpRequest";
	}
	if(defined($csrfToken)){
		$header->{"X_CSRFToken"} = $csrfToken; 
	}
	
	my $param = {
					"url"        	=> $url,
					"timeout"    	=> 3,
					"method"     	=> "POST",                                                                                 
					"header"     	=> $header, 
					"data"       	=> $postData, 
					"httpversion" 	=> "1.1"
				};
				
	if(AttrVal($name, "expert", 0)){
		$param->{"loglevel"} = AttrVal($name, "verbose", 4);
	}
	else{
		$param->{"loglevel"} = 4;
	}
	 	
	
	if(defined($hideurl)){
		$param->{"hideurl"} = 1;
	}

	Log3 $name, 5, $name.": <getHTTPRequest> URL:".$param->{"url"}." send HTTP request:\n## Parameter ##########\n".Dumper($param);                                                         

    my ($err, $data) = HttpUtils_BlockingGet($param);  																					

    if($err ne ""){
        Log3 $name, 1, $name.": error while HTTP requesting ".$param->{"url"}." - $err"; 
        return (undef, undef);
    }
    elsif($data ne ""){
		Log3 $name, 5, $name.": <getHTTPRequest> URL:".$param->{url}." get HTTP returned data: $data";                                                         

        # An dieser Stelle die Antwort parsen / verarbeiten mit $data
       	if($param->{code}==200){ 
			my $responseData = decode_json($data);

			if(defined($responseData)){
				Log3 $name, 5, $name.": <getHTTPRequest> URL:".$param->{"url"}." get HTTP returned:\n## Parameter ##########\n".Dumper($param)."\n## Data ##############\n".Dumper($responseData);                                                         
				return ($responseData, $param); #Übergabe der Referenzen (Scalar)
			}
			else{
				Log3 $name, 1, $name.": error while HTTP requesting URL:".$param->{"url"}." - no JSON data!";
				return (undef, undef);
			}
		}else{
			Log3 $name, 1, $name.": error while HTTP requesting URL:".$param->{"url"}." - Bad Request ".$param->{code};
			return (undef, undef);
		}
    }
    Log3 $name, 1, $name.": error while HTTP requesting URL:".$param->{"url"}." - no data!";
    return (undef, undef);
}

sub MagentaTV_setCookies {
    my ($hash, $header) = @_;
    my $name = $hash->{NAME};
    
    Log3 $name, 5, $name.": <setCookies> start ";
    
    if($header =~ m/Set-Cookie:/){
		readingsBeginUpdate($hash);
		readingsBulkUpdate($hash, "CSESSIONID", undef, 1);
		readingsBulkUpdate($hash, "CSRFSESSION", undef, 1);
		readingsBulkUpdate($hash, "JSESSIONID", undef, 1);
		readingsEndUpdate($hash, 1);
	
		my $cookies;
		foreach my $cookie ($header =~ m/Set-Cookie: ?(.*)/gi) {
			$cookie =~ /([^,; ]+)=([^,;\s\v]+)[;,\s\v]*([^\v]*)/;
			Log3 $name, 4, $name.": <setCookies> parsed Cookie: $1 Wert = $2 Rest = $3";
			if(($1 eq "CSESSIONID") || ($1 eq "CSRFSESSION") || ($1 eq "JSESSIONID")){
				readingsSingleUpdate($hash,$1,$2,1);
			}
			else{
				Log3 $name, 4, $name.": <setCookies> parsed unknown Cookie: $1 Wert = $2 Rest = $3";
			}
		}      
    }
    else{
    	Log3 $name, 4, $name.": <setCookies> no Cookie to set.";
    }

    return;
}

sub MagentaTV_getCookies {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $cookie;
    my ($csessionid, $csrfsession, $jsessionid);
    
    Log3 $name, 5, $name.": <getCookies> start ";
    
    $csessionid		= ReadingsVal($name, "CSESSIONID", "");
    $csrfsession	= ReadingsVal($name, "CSRFSESSION", "");
    $jsessionid		= ReadingsVal($name, "JSESSIONID", "");
    
    if($csessionid && $csrfsession && $jsessionid){
    	$cookie = "CSESSIONID=".$csessionid."; ";
    	$cookie .= "CSRFSESSION=".$csrfsession."; ";
		$cookie .= "JSESSIONID=".$jsessionid."; ";
		$cookie .= "JSESSIONID=".$jsessionid;
    }
    elsif(!$csessionid && !$csrfsession && $jsessionid){
    	$cookie = "JSESSIONID=".$jsessionid;
    }
    	
    return $cookie;
}

# Login ########################################################################

sub MagentaTV_getCredentials {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my ($url, $postData, $xml, $cookie, $csrfToken, $hideurl);
	my ($responseData, $param);
	my $err;
	
	readingsSingleUpdate($hash,"state","start of login",1);
	
	#noch laufende Timer löschen
	RemoveInternalTimer($hash, "MagentaTV_getCredentials");
	RemoveInternalTimer($hash, "MagentaTV_HeartBit");
	
	#Login
	Log3 $name, 5, $name.": <getCredentials> start step 1 - Login";

	#$url = HOST."/EPG/JSON/Login?&T=".BROWSER;
	$url = HOST_LOGIN."/EPG/JSON/Login?UserID=Guest";
		
	$Login{mac} = ReadingsVal($name, "physicalDeviceId", "00:00:00:00:00:00");    #abgekürztes Verfahren
	
	$postData = encode_json(\%Login);
	$cookie = MagentaTV_getCookies($hash);
	$csrfToken = ReadingsVal($name, "CSRFSESSION", undef);
	
	($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, 1, $cookie, $csrfToken); #$hash, $url, $postData, $xml, $cookie, $csrfToken, $hideurl

	if (!defined($param)){
		MagentaTV_ConnectionFailed($hash);
		return undef;
	}
	#Set Cookie
	MagentaTV_setCookies($hash, $param->{httpheader});
	
	# für Get
	$hash->{helper}{Login} = $responseData;

	if(exists($responseData->{"sam3Para"})){
		#SAM Daten umwandeln 
		my %sam3Para = map { $_->{key} => $_->{value} } @{$responseData->{sam3Para}};	
		$responseData->{sam3Para} = \%sam3Para;
	}
	else{
		Log3 $name, 1, $name.": URL:".$param->{url}." Login returned: no Data";
		readingsSingleUpdate($hash,"lastRequestError","Login returned - no Data",1);
		readingsSingleUpdate($hash,"state","Login failed, no Data!",1);
		#ToDo was soll passieren?
		return undef;
	}
			
	#Authenticate
	Log3 $name, 5, $name.": <getCredentials> start step 2 - Authenticate";

	if(!defined(ReadingsVal($name, "physicalDeviceId", undef))){ 
		#$url = HOST."/EPG/JSON/Authenticate?SID=firstup&T=".BROWSER;
		#$hash->{helper}{Login}{epghttpsurl}."/EPG/JSON/DTAuthenticate?SID=user&T=".BROWSER;
		$url = $hash->{helper}{Login}{epghttpsurl}."/EPG/JSON/Authenticate?SID=firstup&T=".BROWSER;

		$postData = encode_json(\%Authenticate);
		$cookie = MagentaTV_getCookies($hash);
		$csrfToken = ReadingsVal($name, "CSRFSESSION", undef);
	
		($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, 1, $cookie, $csrfToken);

		if (!defined($param)){
			MagentaTV_ConnectionFailed($hash);
			return undef;
		}
		#Set Cookie
		MagentaTV_setCookies($hash, $param->{httpheader});
	
		# für Get
		$hash->{helper}{authenticate} = $responseData;
	
		#retcode":"0","retmsg":"authenticate success ."
		if(exists($responseData->{"retcode"})){
			if($responseData->{"retcode"} ne "0"){
				if(exists($error{Authenticate}{$responseData->{"retcode"}})) {
					$err = $error{Authenticate}{$responseData->{"retcode"}}{"t"}.". ".$error{Authenticate}{$responseData->{"retcode"}}{"m"};
				}
				else{
					$err = $error{Authenticate}{"default"}{"t"}.". ".$error{Authenticate}{"default"}{"m"};
				}
				Log3 $name, 1, $name.": URL:".$param->{url}." Authenticate returned: ".$responseData->{"retmsg"}." - ".$responseData->{"retcode"}." - ".$err;
				readingsSingleUpdate($hash,"lastRequestError",$responseData->{"retcode"}." - ".$responseData->{"retmsg"}." - ".$err,1);
				readingsSingleUpdate($hash,"state","Authenticate failed",1);
				#ToDo was soll passieren?
				return undef;
			}
		}
	}
	else{
		Log3 $name, 5, $name.": <getCredentials> start step 2 - overjump Authenticate";
	}
	
	#Token
	Log3 $name, 5, $name.": <getCredentials> start step 3 - Token";
	
	$url = $hash->{helper}{Login}{sam3Para}{SAM3ServiceURL}."/oauth2/tokens";
    
	my $username = $hash->{helper}{username};
	my $password = $hash->{helper}{password};

	if (!$username || !$password){
        Log3 $name, 1, $name.": no username or password set"; 
        readingsSingleUpdate($hash,"state","Login failed",1);
        return undef;
	}
	$username = MagentaTV_decrypt( $username );
	$password = MagentaTV_decrypt( $password );
    
    $postData = "grant_type=password&username=";
    $postData .= urlEncode($username);  
    $postData .= "&password=";
    $postData .= urlEncode($password);
    $postData .= "&scope=";
    $postData .= $hash->{helper}{Login}{sam3Para}{OAuthScope};
    $postData .= "%20offline_access&client_id=";
    $postData .= CLIENT_ID;
    $postData .= "&x_telekom.access_token.format=CompactToken&x_telekom.access_token.encoding=text%2Fbase64";

	$cookie = MagentaTV_getCookies($hash);

	($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, undef, $cookie);
	
	if (!defined($param)){
		MagentaTV_ConnectionFailed($hash);
		return undef;
	}

	# für Get
	$hash->{helper}{Token} = $responseData;
	
	if(exists($responseData->{"error_description"})){
		Log3 $name, 1, $name.": URL:".$param->{url}." Token returned: ".$responseData->{"error_description"};
		readingsSingleUpdate($hash,"lastRequestError",$responseData->{"error"}." - ".$responseData->{"error_description"},1);
		readingsSingleUpdate($hash,"state","Login failed, wrong username or password!",1);
		#ToDo was soll passieren?
		return undef;
	}
	
	readingsSingleUpdate($hash,"expires_in",$responseData->{"expires_in"},1);  #"expires_in": 7200,
	
	#DTAuthenticate
	Log3 $name, 5, $name.": <getCredentials> start step 4 - DTAuthenticate";
	
	$url = $hash->{helper}{Login}{epghttpsurl}."/EPG/JSON/DTAuthenticate?SID=user&T=".BROWSER;
	
	$cookie = MagentaTV_getCookies($hash);
	$csrfToken = ReadingsVal($name, "CSRFSESSION", "");
	$DTAuthenticate{accessToken} = $hash->{helper}{Token}{access_token};
	
	$DTAuthenticate{terminalid} = ReadingsVal($name, "physicalDeviceId", "");
	$DTAuthenticate{mac} = ReadingsVal($name, "physicalDeviceId", "");
	$DTAuthenticate{caDeviceInfo}[0]{caDeviceId} = ReadingsVal($name, "physicalDeviceId", "");
	$DTAuthenticate{terminalDetail}[4]{value} = ReadingsVal($name, "physicalDeviceId", "");

	$postData = encode_json(\%DTAuthenticate);
	
	($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, 1, $cookie, $csrfToken);

	if (!defined($param)){
		MagentaTV_ConnectionFailed($hash);
		return undef;
	}
	#Set Cookie
	MagentaTV_setCookies($hash, $param->{httpheader});

	# für Get
	$hash->{helper}{DTAuthenticate} = $responseData;

	if(exists($responseData->{"userID"})){
		readingsSingleUpdate($hash,"userID",$responseData->{"userID"},1);
		$hash->{helper}{userID} = uc(md5_hex($responseData->{"userID"})); #md5 von userID
	}
	else{
		readingsSingleUpdate($hash,"userID","fail",1);
	}
	if(exists($responseData->{"deviceId"})){
		$hash->{deviceId} = $responseData->{"deviceId"};	
	}
	else{
		$hash->{deviceId} = "fail";
	}
	
	#retcode":"0","retmsg":"authenticate success ."
	if(exists($responseData->{"retcode"})){
		if($responseData->{"retcode"} ne "0"){
			if(exists($error{Authenticate}{$responseData->{"retcode"}})) {
				$err = $error{Authenticate}{$responseData->{"retcode"}}{"t"}.". ".$error{Authenticate}{$responseData->{"retcode"}}{"m"};
			}
			else{
				$err = $error{Authenticate}{"default"}{"t"}.". ".$error{Authenticatet}{"default"}{"m"};
			}
			Log3 $name, 1, $name.": URL:".$param->{url}." DTAuthenticate returned: ".$responseData->{"retmsg"}." - ".$responseData->{"retcode"}." - ".$err;
			readingsSingleUpdate($hash,"lastRequestError",$responseData->{"retcode"}." - ".$responseData->{"retmsg"}." - ".$err,1);
			readingsSingleUpdate($hash,"state","DTAuthenticate failed",1);
			#ToDo nochmal?
			#ToDo ID löschen?
			
			#33619984 - Login nicht möglich. Login nicht möglich. Bitte versuchen Sie es später erneut.
			#33619984 - Es ist ein Fehler aufgetreten - Max. Anzahl an Geräten erreicht. Bitte löschen Sie nicht mehr benötigte Geräte.
			
			#33619984 ....auch wenn physicalDeviceId falsch
			
			#Anmeldung nochmal probieren oder ReplaceDevice auslösen
			if($responseData->{"retcode"} eq "33619984"){
				readingsSingleUpdate($hash,"state","DTAuthenticate failed, retries to get new credentials in 5min",1);
				#ID löschen
				readingsDelete($hash, "physicalDeviceId");
				#Login nochmal versuchen
				InternalTimer(gettimeofday() + 5*60, "MagentaTV_getCredentials", $hash); #nach 5min nochmal probieren
			}
			#ToDo Test ob hier Abbruch
			#ToDo was soll passieren?
			return undef;
		}
	}
	
	#HeartBit First
	Log3 $name, 5, $name.": <getCredentials> start step 5 - HeartBit";
	
	$url = $hash->{helper}{Login}{epghttpsurl}."/EPG/JSON/HeartBit?SID=first&T=".BROWSER;
	
	$HeartBit{"userid"} = ReadingsVal($name, "userID", "");
	$postData = encode_json(\%HeartBit);
	$cookie = MagentaTV_getCookies($hash);
	$csrfToken = ReadingsVal($name, "CSRFSESSION", undef);
	
	($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, 1, $cookie, $csrfToken);
	if (!defined($param)){
		MagentaTV_ConnectionFailed($hash);
		return undef;
	}

	# für Get
	$hash->{helper}{HeartBit} = $responseData;
	
	if(exists($responseData->{"retcode"})){
		Log3 $name, 1, $name.": URL:".$param->{url}." HeartBit returned: ".$responseData->{"retcode"}." - ".$responseData->{"errorCode"}." - ".$responseData->{"desc"};
		readingsSingleUpdate($hash,"lastRequestError",$responseData->{"retcode"}." - ".$responseData->{"errorCode"}." - ".$responseData->{"desc"},1);
		readingsSingleUpdate($hash,"state","HeartBit failed",1);
		#ToDo was soll passieren?
		return undef;
	}

	readingsSingleUpdate($hash,"nextcallinterval",$responseData->{"nextcallinterval"},1); #nextcallinterval":"900"
	
	#DeviceList holen
	Log3 $name, 5, $name.": <getCredentials> start step 6 - DeviceList";
	unless(MagentaTV_getDeviceList($hash)){
		#ToDo was soll passieren?
		return undef;
	}
	
	#ChannelInfo holen
	Log3 $name, 5, $name.": <getCredentials> start step 7 - ChannelInfo";
	unless(MagentaTV_getChannelInfo($hash)){
		#ToDo was soll passieren?
		return undef;
	}
	
	#SubmitDeviceInfo
	Log3 $name, 5, $name.": <getCredentials> start step 8 - SubmitDeviceInfo";
	
	$url = $hash->{helper}{Login}{epghttpsurl}."/EPG/JSON/SubmitDeviceInfo?&T=".BROWSER;
	
	#userID + deviceID prüfen
	#IMDomain noch holen, jetzt fest codiert
	$SubmitDeviceInfo{"deviceToken"} = ReadingsVal($name, "userID", "")."\@slbnimfk11100.prod.sngtv.t-online.de/".$hash->{deviceId};  	#120049010000000064539033@slbnimfk11100.prod.sngtv.t-online.de/1049440360
																																						#"key": "IMDomain",
                    																																	#"value": "slbnimfk11100.prod.sngtv.t-online.de"
	$SubmitDeviceInfo{"tokenExpireTime"} = POSIX::strftime("%Y%m%d%H%M%S",gmtime(gettimeofday()+30*24*60*60));  #ToDo 1 Monat addieren 
	$postData = encode_json(\%SubmitDeviceInfo);
	$cookie = MagentaTV_getCookies($hash);
	$csrfToken = ReadingsVal($name, "CSRFSESSION", undef);
	
	($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, 1, $cookie, $csrfToken);

	if (!defined($param)){
		MagentaTV_ConnectionFailed($hash);
		return undef;
	}

	# für Get
	$hash->{helper}{SubmitDeviceInfo} = $responseData;
	
	if(exists($responseData->{"retcode"})){
		if($responseData->{"retcode"} ne "0"){
			Log3 $name, 1, $name.": URL:".$param->{url}." SubmitDeviceInfo returned: ".$responseData->{"retcode"}." - ".$responseData->{"retmsg"};
			readingsSingleUpdate($hash,"lastRequestError",$responseData->{"retcode"}." - ".$responseData->{"retmsg"},1);
			readingsSingleUpdate($hash,"state","SubmitDeviceInfo failed",1);
			#ToDo was soll passieren?
			
			#87031808 - SubmitDeviceInfo fail.  trat mal Nachts 2:00Uhr auf
			#Anmeldung nochmal probieren
			if($responseData->{"retcode"} eq "87031808"){
				readingsSingleUpdate($hash,"state","SubmitDeviceInfo failed, retries to get new credentials in 5min",1);
				#Login nochmal versuchen in 5min
				InternalTimer(gettimeofday() + 5*60, "MagentaTV_getCredentials", $hash); #nochmal in 5min 
			}

			return undef;
		}
	}
	
	#Ende Login
	readingsSingleUpdate($hash,"state","Login successful",1);
	Log3 $name, 3, $name.": state of Login - successful";
	
	#Timer setzen
	InternalTimer(gettimeofday() + ReadingsVal($name, "expires_in", 7200) , "MagentaTV_getCredentials", $hash); #Token erneuern 
	InternalTimer(gettimeofday() + ReadingsVal($name, "nextcallinterval", 900) , "MagentaTV_HeartBit", $hash); #HeartBit starten 

	return 1;
}

sub MagentaTV_HeartBit {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my ($url, $postData, $xml, $cookie, $csrfToken, $hideurl);
	my ($responseData, $param);

	Log3 $name, 5, $name.": <getHeartBit> start";
	
	$url = $hash->{helper}{Login}{epghttpsurl}."/EPG/JSON/HeartBit?SID=interval&T=".BROWSER;
	$HeartBit{"userid"} = ReadingsVal($name, "userID", "");
	$postData = encode_json(\%HeartBit);
	$cookie = MagentaTV_getCookies($hash);
	$csrfToken = ReadingsVal($name, "CSRFSESSION", undef);
	
	($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, 1, $cookie, $csrfToken);

	if (!defined($param)){
		MagentaTV_ConnectionFailed($hash);
		return;
	}

	# für Get
	$hash->{helper}{HeartBit} = $responseData;
	
	if(exists($responseData->{"retcode"})){
		Log3 $name, 1, $name.": URL:".$param->{url}." HeartBit returned: ".$responseData->{"retcode"}." - ".$responseData->{"errorCode"}." - ".$responseData->{"desc"};
		readingsSingleUpdate($hash,"lastRequestError",$responseData->{"retcode"}." - ".$responseData->{"errorCode"}." - ".$responseData->{"desc"},1);
		readingsSingleUpdate($hash,"state","HeartBit failed",1);
		
		#Anmeldung nochmal probieren
		if($responseData->{"errorCode"} eq "85983527"){
			readingsSingleUpdate($hash,"state","HeartBit failed, retries to get new credentials in 10s",1);
			Log3 $name, 3, $name.": state of HeartBit - failed, retries to get new credentials in 10s";
			#ID löschen - nein nur Login sollte es tun
			#readingsDelete($hash, "physicalDeviceId");
			#Login nochmal versuchen
			InternalTimer(gettimeofday() + 10, "MagentaTV_getCredentials", $hash); #nochmal in 10s 
		}
		return;
	}
	
	readingsSingleUpdate($hash,"nextcallinterval",$responseData->{"nextcallinterval"},1); #nextcallinterval":"900"
	
	readingsSingleUpdate($hash,"state","HeartBit successful",1);
	
	#weitere Aktionen
	
	#DeviceList holen
	unless(MagentaTV_getDeviceList($hash)){
		#ToDo was tun?
		return;
	}
	
	#ChannelInfo holen
	unless(MagentaTV_getChannelInfo($hash)){
		#ToDo was tun?
		return;
	}
	
	#Timer setzen
	InternalTimer(gettimeofday() + ReadingsVal($name, "nextcallinterval", 900) , "MagentaTV_HeartBit", $hash); #HeartBit starten
	
	return;
}

sub MagentaTV_ConnectionFailed {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	Log3 $name, 1, $name.": Connection failed";
	readingsSingleUpdate($hash,"lastRequestError","Connection failed",1);
	readingsSingleUpdate($hash,"state","Connection failed",1);
	
	if(AttrVal($name, "retryConnection", 1)){
		Log3 $name, 3, $name.": state of Connection - failed, retries to get new credentials in 5min";
		readingsSingleUpdate($hash,"lastRequestError","Connection failed, retries to get new credentials in 5min",1);
		readingsSingleUpdate($hash,"state","Connection failed, retries to get new credentials in 5min",1);
		#HeartBit Timer löschen
		RemoveInternalTimer($hash, "MagentaTV_HeartBit");
		#ID löschen - nein, weil ja nur die Internetverbindung fehlt, kein Fehler bei Anmeldung
		#readingsDelete($hash, "physicalDeviceId");
		#Login nochmal in 5min versuchen
		InternalTimer(gettimeofday() + 5*60, "MagentaTV_getCredentials", $hash);
	}
	else{
		RemoveInternalTimer($hash, "MagentaTV_HeartBit");
		RemoveInternalTimer($hash, "MagentaTV_getCredentials");
	}
	return; 
}

sub MagentaTV_ReplaceDevice {
	my ($hash, $deviceID) = @_;
	my $name = $hash->{NAME};
	my ($url, $postData, $xml, $cookie, $csrfToken, $hideurl);
	my ($responseData, $param);

	Log3 $name, 5, $name.": <ReplaceDevice> start";
	
	$url = $hash->{helper}{Login}{epghttpsurl}."/EPG/JSON/ReplaceDevice?&T=".BROWSER;
	$ReplaceDevice{"orgDeviceId"} = $deviceID;	
	$ReplaceDevice{"userid"} = ReadingsVal($name, "userID", "");	
	$postData = encode_json(\%ReplaceDevice);
	$cookie = MagentaTV_getCookies($hash);
	$csrfToken = ReadingsVal($name, "CSRFSESSION", undef);
	
	($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, 1, $cookie, $csrfToken);

	if (!defined($param)){
		readingsSingleUpdate($hash,"lastRequestError","ReplaceDevice - Connection failed",1);
		return;
	}

	# für Get
	$hash->{helper}{ReplaceDevice} = $responseData;
	
	if(exists($responseData->{"retcode"})){
		if($responseData->{"retcode"} ne "0"){
			Log3 $name, 1, $name.": URL:".$param->{url}." ReplaceDevice returned: ".$responseData->{"retcode"};
			readingsSingleUpdate($hash,"lastRequestError",$responseData->{"retcode"},1);
			readingsSingleUpdate($hash,"state","ReplaceDevice failed",1);
			#ToDo was tun?
			return;
		}
	}
	
	MagentaTV_getCredentials($hash);
		
	return;
}

sub MagentaTV_Logout {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my ($url, $postData, $xml, $cookie, $csrfToken, $hideurl);
	my ($responseData, $param);

	Log3 $name, 5, $name.": <Logout> start";
	
	$url = $hash->{helper}{Login}{epghttpsurl}."/EPG/JSON/Logout?&T=".BROWSER;
	$postData = encode_json(\%Logout);
	$cookie = MagentaTV_getCookies($hash);
	$csrfToken = ReadingsVal($name, "CSRFSESSION", undef);
	
	($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, 1, $cookie, $csrfToken);

	if (!defined($param)){
		readingsSingleUpdate($hash,"lastRequestError","Logout - Connection failed",1);
		return;
	}

	# für Get
	$hash->{helper}{Logout} = $responseData;
	
	if(exists($responseData->{"retcode"})){
		if($responseData->{"retcode"} ne "0"){
			Log3 $name, 1, $name.": URL:".$param->{url}." Logout returned: ".$responseData->{"retcode"};
			readingsSingleUpdate($hash,"lastRequestError",$responseData->{"retcode"},1);
			readingsSingleUpdate($hash,"state","Logout failed",1);
			return;
		}
	}
	
	#noch laufende Timer löschen
	RemoveInternalTimer($hash, "MagentaTV_getCredentials");
	RemoveInternalTimer($hash, "MagentaTV_HeartBit");
	
	readingsSingleUpdate($hash,"state","Logout successful",1);
	
	return;
}

# Data #########################################################################

sub MagentaTV_getDeviceList {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my ($url, $postData, $xml, $cookie, $csrfToken, $hideurl);
	my ($responseData, $param);
	my $err;

	#DeviceList	
	#"deviceType" 	=> "0;2;17"
    # deviceType 0 	=> Receiver
    # deviceType 2 	=> Mobile Apps und Web
    # deviceType 17 => ???
	Log3 $name, 5, $name.": <getDeviceList> start";
	
	$url = $hash->{helper}{Login}{epghttpsurl}."/EPG/JSON/GetDeviceList?SID=user&T=".BROWSER; #EPG/JSON/GetDeviceList?SID=firstall&T=Mac_safari_13

	$DeviceList{"userid"} = ReadingsVal($name, "userID", "");
	$postData = encode_json(\%DeviceList);
	$cookie = MagentaTV_getCookies($hash);
	$csrfToken = ReadingsVal($name, "CSRFSESSION", undef);
	
	($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, 1, $cookie, $csrfToken);
	
	if (!defined($param)){
		readingsSingleUpdate($hash,"lastRequestError","DeviceList - Connection failed",1);
		return undef;
	}

	# für Get
	$hash->{helper}{DeviceList} = $responseData;
	
	if(exists($responseData->{"retcode"})){
		if($responseData->{"retcode"} ne "0"){
			#ToDo Fehler anschauen
			if(exists($error{DeviceList}{$responseData->{"retcode"}})) {
				$err = $error{DeviceList}{$responseData->{"retcode"}}{"t"}.". ".$error{DeviceList}{$responseData->{"retcode"}}{"m"};
			}
			else{
				$err = $error{DeviceList}{"default"}{"t"}.". ".$error{DeviceList}{"default"}{"m"};
			}
			Log3 $name, 1, $name.": URL:".$param->{url}." DeviceList returned: ".$responseData->{"retcode"}." - ".$err;
			readingsSingleUpdate($hash,"lastRequestError",$responseData->{"retcode"}." - ".$err,1);
			readingsSingleUpdate($hash,"state","DeviceList failed",1);
			return undef;
		}
	}
	
	#Auswertung
	#eigene physicalDeviceId
	foreach my $device (@{$responseData->{deviceList}} ) {
		if($device->{deviceId} eq $hash->{deviceId}){
			readingsSingleUpdate($hash,"physicalDeviceId",$device->{physicalDeviceId},1);
		}
   	}
	
	return 1;
}

# EPG ##########################################################################

sub MagentaTV_getChannelInfo {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my ($url, $postData, $xml, $cookie, $csrfToken, $hideurl);
	my ($responseData, $param);

	Log3 $name, 5, $name.": <getChannelInfo> start";
	
	$hash->{channels} = "";	
	
	$url = $hash->{helper}{Login}{epghttpsurl}."/EPG/JSON/AllChannel?SID=user&T=".BROWSER; 
	
	$postData = encode_json(\%ChannelInfo);
	$cookie = MagentaTV_getCookies($hash);
	$csrfToken = ReadingsVal($name, "CSRFSESSION", undef);
	
	($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, 1, $cookie, $csrfToken);
	
	if (!defined($param)){
		readingsSingleUpdate($hash,"lastRequestError","ChannelInfo - Connection failed",1);
		return undef;
	}

	# für Get
	$hash->{helper}{ChannelInfo} = $responseData;
	#$hash->{helper}{ChannelInfo}{info} = POSIX::strftime("%H:%M:%S",localtime(gettimeofday()));
	
	if(exists($responseData->{"retcode"})){
		if($responseData->{"retcode"} ne "0"){
			#ToDo Fehler anschauen
			Log3 $name, 1, $name.": URL:".$param->{url}." ChannelInfo returned: ".$responseData->{"retcode"}." - ".$responseData->{"errorCode"}." - ".$responseData->{"desc"};
			readingsSingleUpdate($hash,"lastRequestError",$responseData->{"retcode"}." - ".$responseData->{"errorCode"}." - ".$responseData->{"desc"},1);
			return undef;
		}
	}
	
	#Auswertung
	$hash->{channels} = $responseData->{counttotal};	
	$hash->{helper}{channellist} = $responseData->{channellist};
	
	return 1;
}

sub MagentaTV_getCustomChanNo {
	#Hash of Receiver
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my ($url, $postData, $xml, $cookie, $csrfToken, $hideurl);
	my ($responseData, $param);
	
	#ToDo: Aufruf nach Abruf von DeviceList + 5s, alle Geräte in Schleife - nein, ich hänge es an den Receiver

	Log3 $name, 5, $name.": <getCustomChanNo> start";

   # hash vom ACCOUNT 
  	my $hashAccount = MagentaTV_getHashOfAccount($hash);
  	my $nameAccount = $hashAccount->{NAME};
	
	$url = $hashAccount->{helper}{Login}{epghttpsurl}."/EPG/JSON/GetCustomChanNo?SID=user&T=".BROWSER; 
	$CustomChanNo{"deviceId"} = $hash->{deviceId};
	$CustomChanNo{"channelNamespace"} = $hash->{channelNamespace};
	$postData = encode_json(\%CustomChanNo);
	$cookie = MagentaTV_getCookies($hashAccount);
	$csrfToken = ReadingsVal($nameAccount, "CSRFSESSION", undef);
	
	($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, 1, $cookie, $csrfToken);

	if (!defined($param)){
		readingsSingleUpdate($hash,"lastRequestError","CustomChanNo - Connection failed",1);
		return undef;
	}
	
	# für Get
	$hash->{helper}{CustomChannels}{value} = $responseData;
	$hash->{helper}{CustomChannels}{timestamp} = POSIX::strftime("%H:%M:%S",localtime(gettimeofday()));

	if(exists($responseData->{"retcode"})){
		if($responseData->{"retcode"} ne "0"){
			#ToDo Fehler anschauen
			if(exists($responseData->{"retmsg"})){
				Log3 $name, 1, $name.": URL:".$param->{url}." CustomChanNo returned: ".$responseData->{"retcode"}." - ".$responseData->{"retmsg"};
				readingsSingleUpdate($hash,"lastRequestError",$responseData->{"retcode"}." - ".$responseData->{"retmsg"},1);
			}
			else{
				Log3 $name, 1, $name.": URL:".$param->{url}." CustomChanNo returned: ".$responseData->{"retcode"}." - no information in response data";
				readingsSingleUpdate($hash,"lastRequestError",$responseData->{"retcode"}." - no information in response data",1);
			}
			return undef;
		}
	}
	
	#Auswertung
	$hash->{helper}{customChanNo} = $responseData->{customChanNo};
	
	return 1;
}

sub MagentaTV_getFavorite {
	#Hash of Receiver
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my ($url, $postData, $xml, $cookie, $csrfToken, $hideurl);
	my ($responseData, $param);
	
	Log3 $name, 5, $name.": <getFavorite> start";

    # hash vom ACCOUNT 
  	my $hashAccount = MagentaTV_getHashOfAccount($hash);
  	my $nameAccount = $hashAccount->{NAME};

	$url = $hashAccount->{helper}{Login}{epghttpsurl}."/EPG/JSON/GetFavorite?&T=".BROWSER; 
	$postData = encode_json(\%favorite);
	$cookie = MagentaTV_getCookies($hashAccount);
	$csrfToken = ReadingsVal($nameAccount, "CSRFSESSION", undef);
	
	($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, 1, $cookie, $csrfToken);

	if (!defined($param)){
		readingsSingleUpdate($hash,"lastRequestError","Favorite - Connection failed",1);
		return undef;
	}

	#für Get
	$hash->{helper}{Favorites}{value} = $responseData;
	$hash->{helper}{Favorites}{timestamp} = POSIX::strftime("%H:%M:%S",localtime(gettimeofday()));
	
	if(exists($responseData->{"retcode"})){
		if($responseData->{"retcode"} ne "0"){
			#ToDo Fehler anschauen
			if(exists($responseData->{"retmsg"})){
				Log3 $name, 1, $name.": URL:".$param->{url}." Favorite returned: ".$responseData->{"retcode"}." - ".$responseData->{"retmsg"};
				readingsSingleUpdate($hash,"lastRequestError",$responseData->{"retcode"}." - ".$responseData->{"retmsg"},1);
			}
			else{
				Log3 $name, 1, $name.": URL:".$param->{url}." Favorite returned: ".$responseData->{"retcode"}." - no information in response data";
				readingsSingleUpdate($hash,"lastRequestError",$responseData->{"retcode"}." - no information in response data",1);
			}
			return undef;
		}
	}
	
	#Auswertung
	$hash->{helper}{favoritelist} = $responseData->{favoritelist};
	
	return 1;
}

sub MagentaTV_getPlayBillContextEx {
	#Hash of Receiver
	my ($hash, $channelid, $programStart) = @_;
	my $name = $hash->{NAME};
	my ($url, $postData, $xml, $cookie, $csrfToken, $hideurl);
	my ($responseData, $param);
	my $channelIdHash;

	Log3 $name, 5, $name.": <getPlayBillContextEx> start";
	
	unless(defined($channelid)){
		Log3 $name, 1, $name.": PlayBillContextEx - no channelId defined";
		readingsSingleUpdate($hash,"lastRequestError"," PlayBillContextEx - no channelId defined",1);
		return undef;
	}

    # hash vom ACCOUNT 
  	my $hashAccount = MagentaTV_getHashOfAccount($hash);
  	
	$url = $hashAccount->{helper}{Login}{epghttpsurl}."/EPG/JSON/PlayBillContextEx?SID=firstplaycontext&T=".BROWSER; 
  	
  	if(defined($programStart)){
  		$programStart =~ s/\//-/g;
		$programStart = str2time($programStart, 'GMT');
		$PlayBillContextEx{"date"} = POSIX::strftime("%Y%m%d%H%M%S",gmtime($programStart));
  	}
  	else{
  		$PlayBillContextEx{"date"} = POSIX::strftime("%Y%m%d%H%M%S",gmtime(gettimeofday()));
  	}
	$PlayBillContextEx{"channelid"} = $channelid;
	$postData = encode_json(\%PlayBillContextEx);
	$cookie = MagentaTV_getCookies($hashAccount);
	$csrfToken = ReadingsVal($hashAccount->{NAME}, "CSRFSESSION", undef);
	
	($responseData, $param) = MagentaTV_getHTTPRequest($hash, $url, $postData, 1, $cookie, $csrfToken);
	#ToDo: wo anzeigen?- MagentaTV_ConnectionFailed($hash) ausführen? - nein,vorerst
	if (!defined($param)){
		readingsSingleUpdate($hash,"lastRequestError","PlayBillContextEx - Connection failed",1);
		return undef;
	}

	#für Get
	$hash->{helper}{PlayBillContextEx}{value} = $responseData;
	$hash->{helper}{PlayBillContextEx}{timestamp} = POSIX::strftime("%H:%M:%S",localtime(gettimeofday()));

		if(exists($responseData->{"retcode"})){
		if($responseData->{"retcode"} ne "0"){
			#ToDo Fehler anschauen
			Log3 $name, 1, $name.": URL:".$param->{url}." PlayBillContextEx returned: ".$responseData->{"errorCode"}." - ".$responseData->{"desc"};
			readingsSingleUpdate($hash,"lastRequestError",$responseData->{"errorCode"}." - ".$responseData->{"desc"},1);
			return undef;
		}
	}
	
	#Auswertung
	$hash->{helper}{EPG}{current} = $responseData->{current};
	$hash->{helper}{EPG}{nextList} = $responseData->{nextList}[0];

	$channelIdHash = MagentaTV_channelId2hash($hash,$channelid);
					
	$hash->{helper}{EPG}{logo} = $channelIdHash->{logo};
	$hash->{helper}{EPG}{sendername} = $channelIdHash->{channelName};
	$hash->{helper}{EPG}{format} = $channelIdHash->{format};
	
	#MagentaTV_TriggerDetailFn($hash);
	#Trigger wird individuel gesetzt
	return 1;
}



################################################################################
# RECEIVER #####################################################################
################################################################################

# SOAP Request #################################################################

sub MagentaTV_sendSOAPRequest {
    my ($hash, $url, $action, $body) = @_;
    my $name = $hash->{NAME};
    
    Log3 $name, 5, $name.": <sendSOAPRequest> start ";
    
    my $header = {
					"USER-AGENT" 	=> USER_AGENT,
			 	 	"CONTENT-TYPE" 	=> 'text/xml; charset="utf-8"',
			 	 	"SOAPACTION" 	=> $action,
			 	 	"CONNECTION" 	=> "close"
			 	 };
    
    my $postData = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>';
    $postData .= $body;
    $postData .= '</s:Body></s:Envelope>';
    
    my $param = {
	                url        => $url,
	                timeout    => 1,
	                method     => "POST",                                                                                 
	                header     => $header, 
	                data       => $postData,
	                httpversion => "1.1" 
	            };
	            
    Log3 $name, 5, $name.": <sendSOAPRequest> URL:".$param->{url}." \n SOAP request send: ".$postData;	
    
    my ($err, $data) = HttpUtils_BlockingGet($param); 
     
    if($err ne ""){
        Log3 $name, 1, $name.": error while SOAP requesting ".$param->{url}." - $err"; 
        return undef;
    }
    elsif($data ne ""){
        Log3 $name, 5, $name.": <sendSOAPRequest> URL:".$param->{url}." \n SOAP request data: $data";                                                        
        # An dieser Stelle die Antwort parsen / verarbeiten mit $data
        if($param->{code}==200){
			return $data;
		}
# 		else{
# 			Log3 $name, 1, $name.": URL:".$param->{url}." \n SOAP request returned: ".$param->{code}." Bad Request";
# 			return undef;
# 		}
    }
    Log3 $name, 1, $name.": URL:".$param->{url}." \n SOAP request returned: ".$param->{code}." Bad Request";
	return undef;
}

# Pairing ######################################################################

sub MagentaTV_pairingRequest {
	my ($hash) = @_;
    my $name = $hash->{NAME};
    
    my $return;
    
    Log3 $name, 5, $name.": <pairingRequest> start step 1";
    
    if($hash->{STATE} eq "offline"){
    	Log3 $name, 1, $name.": pairing only possible if device online or in standby";
    	return undef;
    }

 	$hash->{helper}{Pairing}{RUN} = 1;  #Pairing läuft
  	
  	# hash vom ACCOUNT für userID
  	my $hashAccount = MagentaTV_getHashOfAccount($hash);
	
	# url
  	my $service = MagentaTV_GetUPnPService($hash, "X-CTC_RemotePairing");
  	if(defined($service)){
		my $url = $service->controlURL;
	
		# action
		my $action = '"urn:schemas-upnp-org:service:X-CTC_RemotePairing:1#X-pairingRequest"';
	
		# body   	
		my $pairingDeviceID = $hash->{pairingID};
		my $friendlyName = $hashAccount->{friendlyName}; 
		my $userID = $hashAccount->{helper}{userID}; 
		
		my $body = '<u:X-pairingRequest xmlns:u="urn:schemas-upnp-org:service:X-CTC_RemotePairing:1"><pairingDeviceID>';
		$body .= $pairingDeviceID;
		$body .= "</pairingDeviceID><friendlyName>";
		$body .= $friendlyName;
		$body .= "</friendlyName><userID>";
		$body .= $userID;
		$body .= "</userID></u:X-pairingRequest>";
 
		Log3 $name, 5, $name.": <pairingRequest> URL:$url \n Action:$action \n Body:$body";
 
		$return =  MagentaTV_sendSOAPRequest($hash, $url, $action, $body);
  	}
  	
  	if(defined($return)){
		$return =~ /<result>(.*?)<\/result>/; #<result>0</result>
	
		if($1 ne "0"){
			$hash->{helper}{Pairing}{RUN} = 0;
			readingsSingleUpdate($hash,"pairing","failed",1);
			Log3 $name, 1, $name.": pairing failed - wrong credentials";
		}
  	}
  	else{
		$hash->{helper}{Pairing}{RUN} = 0;
		readingsSingleUpdate($hash,"pairing","failed",1);
		Log3 $name, 1, $name.": pairing failed - wrong code";  	
  	}
  
  	return undef;
}

sub MagentaTV_pairingCheck {
	my ($hash) = @_;
    my $name = $hash->{NAME};
    
    my $return;
    
    Log3 $name, 5, $name.": <pairingCheck> start step 2";
    
    # hash vom ACCOUNT für userID
    my $hashAccount = MagentaTV_getHashOfAccount($hash);
    
    # url
  	my $service = MagentaTV_GetUPnPService($hash, "X-CTC_RemotePairing");
  	if(defined($service)){
		my $url = $service->controlURL;
	
		# action
		my $action = '"urn:schemas-upnp-org:service:X-CTC_RemotePairing:1#X-pairingCheck"';
	
		# body
		my $userID = $hashAccount->{helper}{userID};     
		my $pairingDeviceID = $hash->{pairingID};
		my $pairingCheck = ReadingsVal($name, "pairingCheck", "");
	
		my $verificationCode = uc(md5_hex($pairingCheck.$pairingDeviceID.$userID));  # MD5 hash of <Pairing Code><Terminal-ID><User ID>
		readingsSingleUpdate($hash,"verificationCode",$verificationCode,1); 
	
		my $body = '<u:X-pairingCheck xmlns:u="urn:schemas-upnp-org:service:X-CTC_RemotePairing:1"><pairingDeviceID>';
		$body .= $pairingDeviceID;
		$body .= "</pairingDeviceID><verificationCode>";
		$body .= $verificationCode;
		$body .= "</verificationCode></u:X-pairingCheck>";

		Log3 $name, 5, $name.": <pairingCheck> URL:$url \n Action:$action \n Body:$body";
	
		$return =  MagentaTV_sendSOAPRequest($hash, $url, $action, $body);
  	}

  	if(defined($return)){
  		# <pairingResult>(.*?)</pairingResult>
  		# <Enable4K>1</Enable4K>
		# <EnableSAT>0</EnableSAT>
		$hash->{helper}{pairingCheck} = $return;
		
		if($return =~ /<Enable4K>(.*?)<\/Enable4K>/){
			if($1 eq "1"){$hash->{enable4K} = "enabled"}else{delete($hash->{enable4K})};
		}
		if($return =~ /<EnableSAT>(.*?)<\/EnableSAT>/){
			if($1 eq "1"){$hash->{enableSAT} = "enabled"}else{delete($hash->{enableSAT})};
		}
  		$return =~ /<pairingResult>(.*?)<\/pairingResult>/; 
		if($1 ne "0"){
			$hash->{helper}{Pairing}{RUN} = 0;
			if($1 eq "-1"){
				readingsSingleUpdate($hash,"pairing","failed",1);
				Log3 $name, 1, $name.": pairing failed - expired";
			}
			elsif($1 eq "-2"){
				readingsSingleUpdate($hash,"pairing","failed",1);
				Log3 $name, 1, $name.": pairing failed - wrong credentials";
			}
		}
		else{
			$hash->{helper}{Pairing}{RUN} = 0;
			readingsSingleUpdate($hash,"pairing","paired",1);
			Log3 $name, 3, $name.": pairing OK";

			# EPG Kanalliste holen
			#InternalTimer(gettimeofday() + 4, 'MagentaTV_getSender', $hash, 0);
			#wird schon beim Finden geholt
			
			# PlayerState holen
			InternalTimer(gettimeofday() + 8, 'MagentaTV_getPlayerState', $hash, 0);
		}
	}
	else{
		$hash->{helper}{Pairing}{RUN} = 0;
		readingsSingleUpdate($hash,"pairing","failed",1);
		Log3 $name, 1, $name.": pairing failed - wrong code";
	}
  
  	return undef;
}

# Action Key Request ###########################################################

sub MagentaTV_RemoteKey {
	my ($hash, $key) = @_;
    my $name = $hash->{NAME};
    
    my $return;
    
    Log3 $name, 5, $name.": <RemoteKey> start ";
    
    # wakeOnLan - funktioniert! Nur, das wol den Receiver erst mal aufweckt und in Standby versetzt, er muss nochmals eingeschaltet werden. Klappt nur im "Ruhezustand"
    if($key eq "POWER"){
    	if(defined($hash->{wakeOnLan})){
    		if(($hash->{wakeOnLan} eq "enabled") && ($hash->{STATE} eq "offline")){
    			#ToDo wake evt Net::Wake
    			MagentaTV_wol($name,$hash->{MAC});
    			return undef;
    		}
    	}
    }
    
    if($hash->{STATE} eq "offline"){
    	Log3 $name, 1, $name.": SendKey only possible if device online or in standby";
    	return undef;
    }

 	if(defined($keyMap{$key})){
		# hash vom ACCOUNT für userID
		my $hashAccount = MagentaTV_getHashOfAccount($hash);
	
		# url
		my $service = MagentaTV_GetUPnPService($hash, "X-CTC_RemoteControl");
		if(defined($service)){
			my $url = $service->controlURL;
	
			# action
			my $action = '"urn:schemas-upnp-org:service:X-CTC_RemoteControl:1#X_CTC_RemoteKey"';

			# body  
			$key = $keyMap{$key};	
			my $pairingDeviceID = $hash->{pairingID};
			my $verificationCode = $hash->{READINGS}{verificationCode}{VAL};
			my $userID = $hashAccount->{helper}{userID}; 

			#"<u:X_CTC_RemoteKey xmlns:u=\"urn:schemas-upnp-org:service:X-CTC_RemoteControl:1\"><InstanceID>0</InstanceID><KeyCode>keyCode={0}^{1}:{2}^userID:{3}</KeyCode></u:X_CTC_RemoteKey>";
			my $body = '<u:X_CTC_RemoteKey xmlns:u="urn:schemas-upnp-org:service:X-CTC_RemoteControl:1">';
			$body .= "<InstanceID>0</InstanceID>";
			$body .= "<KeyCode>keyCode=";
			$body .= $key;
			$body .= "^";
			$body .= $pairingDeviceID;
			$body .= ":";
			$body .= $verificationCode;
			$body .= "^userID:";
			$body .= $userID;
			$body .= "</KeyCode></u:X_CTC_RemoteKey>";
 
			Log3 $name, 5, $name.": <RemoteKey> URL:$url \n Action:$action \n Body:$body";
 
			$return =  MagentaTV_sendSOAPRequest($hash, $url, $action, $body);
		} 	
 	}
  	
  	if(defined($return)){
		#<u:X_CTC_RemoteKeyResponse xmlns:u="urn:schemas-upnp-org:service:X-CTC_RemoteControl:1"></u:X_CTC_RemoteKeyResponse>
  	}
  	else{
		Log3 $name, 1, $name.": SendKey - wrong code";
  	}
  
  	return undef;
}

# Action Player State ##########################################################

sub MagentaTV_getPlayerState {
	my ($hash, $forceState) = @_;
    my $name = $hash->{NAME};
    my $match;
    
    my $return;
    
    Log3 $name, 5, $name.": <getPlayerState> start ";
    
    if($hash->{STATE} eq "offline"){
    	Log3 $name, 1, $name.": state of request only possible if device online or in standby";
    	return undef;
    }
	
	# url
  	my $service = MagentaTV_GetUPnPService($hash, "X-CTC_RemotePairing");
  	if(defined($service)){
		my $url = $service->controlURL;
	
		# action
		my $action = '"urn:schemas-upnp-org:service:X-CTC_RemotePairing:1#X-getPlayerState"';
	
		# body   
		my $pairingDeviceID = $hash->{pairingID};
		my $verificationCode = $hash->{READINGS}{verificationCode}{VAL};
			
		my $body = '<u:X-getPlayerState xmlns:u="urn:schemas-upnp-org:service:X-CTC_RemotePairing:1"><pairingDeviceID>';
		$body .= $pairingDeviceID;
		$body .= "</pairingDeviceID><verificationCode>";
		$body .= $verificationCode;
		$body .= "</verificationCode></u:X-getPlayerState>";
 
		Log3 $name, 5, $name.": <getPlayerState> URL:$url \n Action:$action \n Body:$body";
 
		$return =  MagentaTV_sendSOAPRequest($hash, $url, $action, $body);
  	}
  	
  	if(defined($return)){

		$hash->{helper}{getPlayerState} = $return;
		
		if(AttrVal($name, "detectPlayerState", 1)){	
			my $mediaCodeHash;
			my $channelId;
			
			readingsBeginUpdate($hash); 
			
			#MR400	
			if(($return =~ m/<playBackState>0<\/playBackState>/) && !($return =~ m/<mediaType>/) && !($return =~ m/<trickPlayMode>/) && !($return =~ m/<mediaCode>/)){
	 			readingsBulkUpdate($hash, "state", "standby", 1);
				readingsBulkUpdate($hash, "playBackState", $playBackState{0}, 1);
	 			Log3 $name, 3, $name.": state of player state request - standby";
			}	
			elsif(($return =~ m/<playBackState>1<\/playBackState>/) && ($return =~ m/<mediaType>/) && ($return =~ m/<trickPlayMode>/) && ($return =~ m/<mediaCode>/)){	
	 			readingsBulkUpdate($hash, "state", "play", 1);
	 			readingsBulkUpdate($hash, "playBackState", $playBackState{1}, 1);
	 			$return =~ m/<mediaType>(.*?)<\/mediaType>/;
					readingsBulkUpdate($hash, "mediaType", $1, 1);
	 			$return =~ m/<mediaCode>(.*?)<\/mediaCode>/;
					readingsBulkUpdate($hash, "mediaCode", $1, 1);
					$mediaCodeHash = MagentaTV_mediaCode2hash($hash,$1);

					if(defined($mediaCodeHash)){
						readingsBulkUpdate($hash, "channelName", $mediaCodeHash->{channelName}, 1);
						readingsBulkUpdate($hash, "channelCode", $mediaCodeHash->{contentId}, 1);
						readingsBulkUpdate($hash, "chanNo", $mediaCodeHash->{chanNo}, 1);
						readingsBulkUpdate($hash, "channel", $mediaCodeHash->{channel}, 1);
						readingsBulkUpdate($hash, "favorite", $mediaCodeHash->{favorite}, 1);
						
						$channelId = $mediaCodeHash->{contentId};
					}

	 			Log3 $name, 3, $name.": state of player state request - play";	
		 	}
		 	
		 	#MR401
			elsif(($return =~ m/<playBackState>1<\/playBackState>/) && !($return =~ m/<duration>/) && !($return =~ m/<playPostion>/) && ($return =~ m/<mediaCode>/) && ($return =~ m/<mediaType>/)){	
	 			readingsBulkUpdate($hash, "state", "standby", 1);
	 			readingsBulkUpdate($hash, "playBackState", $playBackState{1}, 1);
	 			Log3 $name, 3, $name.": state of player state request - standby";
		 	}
			elsif(($return =~ /<playBackState>1<\/playBackState>/) && ($return =~ /<duration>/) && ($return =~ /<playPostion>/) && ($return =~ /<mediaCode>/) && ($return =~ /<mediaType>/)){	
	 			readingsBulkUpdate($hash, "state", "play", 1);
	 			readingsBulkUpdate($hash, "playBackState", $playBackState{1}, 1);
	 			$return =~ m/<mediaType>(.*?)<\/mediaType>/;
					readingsBulkUpdate($hash, "mediaType", $1, 1);
	 			$return =~ m/<mediaCode>(.*?)<\/mediaCode>/;
					readingsBulkUpdate($hash, "mediaCode", $1, 1);
					$mediaCodeHash = MagentaTV_mediaCode2hash($hash,$1);

					if(defined($mediaCodeHash)){
						readingsBulkUpdate($hash, "channelName", $mediaCodeHash->{channelName}, 1);
						readingsBulkUpdate($hash, "channelCode", $mediaCodeHash->{contentId}, 1);
						readingsBulkUpdate($hash, "chanNo", $mediaCodeHash->{chanNo}, 1);
						readingsBulkUpdate($hash, "channel", $mediaCodeHash->{channel}, 1);
						readingsBulkUpdate($hash, "favorite", $mediaCodeHash->{favorite}, 1);
						
						$channelId = $mediaCodeHash->{contentId};
					}

	 			Log3 $name, 3, $name.": state of player state request - play";
		 	}
		 	
		 	readingsEndUpdate($hash, 1);
		 	
		 	#erst hier Content abfragen, da sonst readingsSingleUpdate Probleme macht
			if(defined($channelId)){
				MagentaTV_getPlayBillContextEx($hash,$channelId); 
			}
			
		 	#detailFn refresh
		 	MagentaTV_TriggerDetailFn($hash);
		}
  	}
  	else{
		Log3 $name, 1, $name.": getPlayerState - wrong code";
  	}
	
	InternalTimer(gettimeofday() + AttrVal($name,"getPlayerStateInterval",60), "MagentaTV_getPlayerState", $hash) if(AttrVal($name,"getPlayerStateInterval",0));
	
  	return undef;
}

# Action GetTransportInfo ######################################################

sub MagentaTV_GetTransportInfo {
	my ($hash) = @_;
    my $name = $hash->{NAME};
    
    my $return;
    
    Log3 $name, 5, $name.": <GetTransportInfo> start ";
    
    if($hash->{STATE} eq "offline"){
    	Log3 $name, 1, $name.": AVTransport > GetTransportInfo only possible if device online or in standby";
    	return undef;
    }

	# url
	my $service = MagentaTV_GetUPnPService($hash, "AVTransport");
	if(defined($service)){
		my $url = $service->controlURL;

		# action
		my $action = '"urn:schemas-upnp-org:service:AVTransport:1#GetTransportInfo"';

		# body  
		my $body = '<u:GetTransportInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">';
		$body .= "<InstanceID>0</InstanceID>";
		$body .= "</u:GetTransportInfo>";

		Log3 $name, 5, $name.": <GetTransportInfo> URL:$url \n Action:$action \n Body:$body";

		$return =  MagentaTV_sendSOAPRequest($hash, $url, $action, $body);
	} 	
  	
  	if(defined($return)){
		$hash->{helper}{GetTransportInfo} = $return;
  	}
  	else{
		Log3 $name, 1, $name.": GetTransportInfo - wrong code";
  	}
  
  	return undef;
}

# Action GetTransportInfo ######################################################

sub MagentaTV_GetTransportSettings {
	my ($hash) = @_;
    my $name = $hash->{NAME};
    
    my $return;
    
    Log3 $name, 5, $name.": <GetTransportSettings> start ";
    
    if($hash->{STATE} eq "offline"){
    	Log3 $name, 1, $name.": AVTransport > GetTransportSettings only possible if device online or in standby";
    	return undef;
    }

	# url
	my $service = MagentaTV_GetUPnPService($hash, "AVTransport");
	if(defined($service)){
		my $url = $service->controlURL;

		# action
		my $action = '"urn:schemas-upnp-org:service:AVTransport:1#GetTransportSettings"';

		# body  
		my $body = '<u:GetTransportSettings xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">';
		$body .= "<InstanceID>0</InstanceID>";
		$body .= "</u:GetTransportSettings>";

		Log3 $name, 5, $name.": <GetTransportSettings> URL:$url \n Action:$action \n Body:$body";

		$return =  MagentaTV_sendSOAPRequest($hash, $url, $action, $body);
	} 	
  	
  	if(defined($return)){
		$hash->{helper}{GetTransportSettings} = $return;
  	}
  	else{
		Log3 $name, 1, $name.": GetTransportSettings - wrong code";
  	}
  
  	return undef;
}


# Action Stop ##################################################################

sub MagentaTV_Stop {
	my ($hash) = @_;
    my $name = $hash->{NAME};
    
    my $return;
    
    Log3 $name, 5, $name.": <Stop> start ";
    
    if($hash->{STATE} eq "offline"){
    	Log3 $name, 1, $name.": AVTransport > Stop only possible if device online or in standby";
    	return undef;
    }

	# url
	my $service = MagentaTV_GetUPnPService($hash, "AVTransport");
	if(defined($service)){
		my $url = $service->controlURL;

		# action
		my $action = '"urn:schemas-upnp-org:service:AVTransport:1#Stop"';

		# body  
		my $body = '<u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">';
		$body .= "<InstanceID>0</InstanceID>";
		$body .= "</u:Stop>";

		Log3 $name, 5, $name.": <Stop> URL:$url \n Action:$action \n Body:$body";

		$return =  MagentaTV_sendSOAPRequest($hash, $url, $action, $body);
	} 	
  	
  	if(defined($return)){
		#
  	}
  	else{
		Log3 $name, 1, $name.": Stop - wrong code";
  	}
  
  	return undef;
}


# Action Play ##################################################################

sub MagentaTV_Play {
	my ($hash) = @_;
    my $name = $hash->{NAME};
    
    my $return;
    
    Log3 $name, 5, $name.": <Play> start ";
    
    if($hash->{STATE} eq "offline"){
    	Log3 $name, 1, $name.": AVTransport > Play only possible if device online or in standby";
    	return undef;
    }

	# url
	my $service = MagentaTV_GetUPnPService($hash, "AVTransport");
	if(defined($service)){
		my $url = $service->controlURL;

		# action
		my $action = '"urn:schemas-upnp-org:service:AVTransport:1#Play"';

		# body  
		my $body = '<u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">';
		$body .= "<InstanceID>0</InstanceID>";
		$body .= "<Speed>1</Speed>";
		$body .= "</u:Play>";

		Log3 $name, 5, $name.": <Play> URL:$url \n Action:$action \n Body:$body";

		$return =  MagentaTV_sendSOAPRequest($hash, $url, $action, $body);
	} 	
  	
  	if(defined($return)){
		#
  	}
  	else{
		Log3 $name, 1, $name.": Play - wrong code";
  	}
  
  	return undef;
}

# Action SetTransportURI #######################################################

sub MagentaTV_SetAVTransportURI {
	my ($hash, $ContentID, $mediaCode) = @_;
    my $name = $hash->{NAME};
    
    my $return;
    
    Log3 $name, 5, $name.": <SetAVTransportURI> start ";
    
    if($hash->{STATE} eq "offline"){
    	Log3 $name, 1, $name.": AVTransport > SetAVTransportURI only possible if device online or in standby";
    	return undef;
    }
    
	# hash vom ACCOUNT für userID
	my $hashAccount = MagentaTV_getHashOfAccount($hash);

	# url
	my $service = MagentaTV_GetUPnPService($hash, "AVTransport");
	if(defined($service)){
		my $url = $service->controlURL;

		# action
		my $action = '"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"';

		# body  
		my $pairingDeviceID = $hash->{pairingID};
		my $verificationCode = $hash->{READINGS}{verificationCode}{VAL};
		my $userID = $hashAccount->{helper}{userID}; 

		#"<u:X_CTC_RemoteKey xmlns:u=\"urn:schemas-upnp-org:service:X-CTC_RemoteControl:1\"><InstanceID>0</InstanceID><KeyCode>keyCode={0}^{1}:{2}^userID:{3}</KeyCode></u:X_CTC_RemoteKey>";
		my $body = '<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">';
		$body .= "<InstanceID>0</InstanceID>";
		$body .= "<CurrentURI>http://1.1.1.1?action=functionCall&amp;functionType=startPlay&amp;";
		$body .= "mediaCode=";
		$body .= $mediaCode;
		$body .= "&amp;mediaType=1&amp;playByBookmark=0&amp;";
		$body .= "ContentID=";
		$body .= $ContentID;
		$body .= "&amp;type=EVENT_REMOTE_CONTROL&amp;playByTime=0&amp;platform=IPTV&amp;";
		$body .= "userID=";
		$body .= $userID;
		$body .= "&amp;pairingInfo=";
		$body .= $pairingDeviceID;
		$body .= ":";
		$body .= $verificationCode;
		$body .= "</CurrentURI>";
		$body .= "<CurrentURIMetaData>&lt;DIDL-Lite xmlns:dc=&quot;http://purl.org/dc/elements/1.1/&quot;    xmlns:upnp=&quot;urn:schemas-upnp-org:metadata-1-0/upnp/&quot;    xmlns=&quot;urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/&quot;&gt; &lt;item id=&quot;10&quot; parentID=&quot;&quot; restricted=&quot;1&quot;&gt; &lt;dc:title&gt;&lt;/dc:title&gt; &lt;upnp:class&gt;&lt;/upnp:class&gt; &lt;res size=&quot;0&quot; protocolInfo=&quot;&quot;&gt;&lt;/res&gt;&lt;/item&gt;&lt;/DIDL-[Lite&gt;</CurrentURIMetaData>";
		$body .= "</u:SetAVTransportURI>";

		Log3 $name, 5, $name.": <SetAVTransportURI> URL:$url \n Action:$action \n Body:$body";

		$return =  MagentaTV_sendSOAPRequest($hash, $url, $action, $body);
	} 	
  	
  	if(defined($return)){
		#
  	}
  	else{
		Log3 $name, 1, $name.": SetAVTransportURI - wrong code";
  	}
  
  	return undef;
}

# Action Play ##################################################################

sub MagentaTV_OpenApp {
	my ($hash, $appId) = @_;
    my $name = $hash->{NAME};
    
    my $return;
    
    Log3 $name, 5, $name.": <OpenApp> start ";
    
    if($hash->{STATE} eq "offline"){
    	Log3 $name, 1, $name.": X-CTC_OpenApp > OpenApp only possible if device online or in standby";
    	return undef;
    }

	# url
	my $service = MagentaTV_GetUPnPService($hash, "X-CTC_OpenApp");
	if(defined($service)){
		my $url = $service->controlURL;

		# action
		my $action = '"urn:schemas-upnp-org:service:X-CTC_OpenApp:1#X-CTC_OpenApp"';

		# body  
		my $body = '<u:X-CTC_OpenApp xmlns:u="urn:schemas-upnp-org:service:X-CTC_OpenApp:1">';
		$body .= "<InstanceID>0</InstanceID>";
		$body .= "<AppId>".$appId."</AppId>";
		$body .= "</u:X-CTC_OpenApp>";

		Log3 $name, 5, $name.": <OpenApp> URL:$url \n Action:$action \n Body:$body";

		$return =  MagentaTV_sendSOAPRequest($hash, $url, $action, $body);
	} 	
  	
  	if(defined($return)){
		#
  	}
  	else{
		Log3 $name, 1, $name.": OpenApp - wrong code";
  	}
  
  	return undef;
}


################################################################################
# UPnP #########################################################################
################################################################################

# UPnP DISCOVERY ###############################################################

sub MagentaTV_setupControlpoint {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    
    Log3 $name, 5, $name.": <setupControlpoint> start setup Upnp ControlPoint";
  
   	my $cp;
  	my @usedonlyIPs = split(/,/, AttrVal($hash->{NAME}, 'usedonlyIPs', ''));
  	my @ignoredIPs = split(/,/, AttrVal($hash->{NAME}, 'ignoredIPs', ''));
  	my $subscriptionPort = AttrVal($hash->{NAME}, 'subscriptionPort', 0);
  	my $searchPort = AttrVal($hash->{NAME}, 'searchPort', 0);
  	my $reusePort = AttrVal($hash->{NAME}, 'reusePort', 0);
  
	eval {
		local $SIG{__WARN__} = sub { die $_[0] };
		
		#maxWait von 30 auf 120 erhöht, MR401 brauchte >30s um sich auf Suchanfrage zu melden
		$cp = UPnP::ControlPoint->new(SubscriptionURL => "/eventSub", ReusePort => $reusePort, SearchPort => $searchPort, SubscriptionPort => $subscriptionPort, MaxWait => 120, UsedOnlyIP => \@usedonlyIPs, IgnoreIP => \@ignoredIPs, LogLevel => AttrVal($hash->{NAME}, 'verbose', 0)); #, EnvPrefix => 's', EnvNamespace => ''
		$hash->{helper}{controlpoint} = $cp;
		
		MagentaTV_addSocketsToMainloop($hash);
	};
  	if($@){
  		Log3 $name, 1, $name.": Upnp ControlPoint setup error => ".$@;
  		return undef;
  	}
  	
  	$hash->{subscriptionURL} = "<".$cp->subscriptionURL.">";
  	
  	Log3 $name, 5, $name.": <setupControlpoint> succesfull setup of Upnp ControlPoint";    
  
  	return 1;
}

sub MagentaTV_startSearch {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    
    #ToDo Loglevel anpassen
    Log3 $name, 5, $name.": <startSearch> start UPnP Search";
	
	#ControlPoint erstellt?
	if (defined($hash->{helper}{controlpoint})) {
		#gibt es schon eine Suche, dann diese stoppen
		if(defined($hash->{helper}{search})){
			$hash->{helper}{controlpoint}->stopSearch($hash->{helper}{search});
			Log3 $hash, 3, $name.": current Upnp Search - stopped";
		} 
	
		my $search;
	  	eval {
	  		local $SIG{__WARN__} = sub { die $_[0] };
	  		
	    	$search = $hash->{helper}{controlpoint}->searchByType('urn:schemas-upnp-org:device:MediaRenderer:1', sub { MagentaTV_discoverCallback($hash, @_); });
	  		$hash->{helper}{search} = $search;
	  	};
	  	if($@) {
	    	Log3 $name, 1, $name.": UPnP Search failed with error $@";
	    	return undef;
	  	}
	  	Log3 $hash, 3, $name.": new Upnp search - started";
  	}
  	else{
    	Log3 $name, 1, $name.": UPnP Search failed, because no Controlpoint was setup";
    	return undef;
  	}
  	
  	Log3 $name, 5, $name.": <startSearch> succesfull setup of Upnp Search";
  	
  	return 1;
}

sub MagentaTV_StopControlPoint {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $err;
    
    Log3 $name, 5, $name.": <StopControlPoint> start ";

	if (defined($hash->{helper}{controlpoint})) {
		$hash->{helper}{controlpoint}->stopSearch($hash->{helper}{search}); 
		$hash->{helper}{controlpoint}->stopHandling();
		my @sockets = $hash->{helper}{controlpoint}->sockets();

	  	eval {
	  		local $SIG{__WARN__} = sub { die $_[0] };
	  		
	  		undef($hash->{helper}{controlpoint});
	  	};
	 	if($@) {
	  		$err = $@;
	  		$err =~ m/^(.*?)\sat\s.*?$/;
	    	Log3 $name, 2, $name.": <MagentaTV_StopControlPoint> stop of control point failed: $1 ";
	  	}
			
		delete($hash->{helper}{controlpoint});
		delete($hash->{helper}{search});
			
		# alle Timer für Subscription anhalten
		for my $receiver (MagentaTV_getAllReceiver($hash)) {
			RemoveInternalTimer($receiver, 'MagentaTV_renewSubscriptions');

			Log3 $name, 5, $name.": <StopControlPoint> RemoveInternalTimer for ".$receiver->{NAME};
		}
  
  		# alle Sockets schließen
  		foreach my $socket (@sockets) {
    		shutdown($socket,2) if($socket);
    		close($socket) if($socket);
    
    		Log3 $name, 5, $name.": <StopControlPoint> socket $socket closed";
  	  	}
  	  	
	  	# alle UPnPSocket löschen
  	  	for my $device (MagentaTV_getAllUPnPSockets($hash)) {
			CommandDelete(undef, $device->{NAME});
			
			Log3 $name, 5, $name.": <StopControlPoint> UPnPSocket hidden device delete ".$device->{NAME};
		}

		Log3 $name, 1, $name.": ControlPoint is successfully stopped!";
		
		CancelDelayedShutdown($name); #für DelayedShutdown
	}
	else{
		Log3 $name, 5, $name.": <StopControlPoint> ControlPoint was not defined!";
	} 
}

sub MagentaTV_discoverCallback {
  	my ($hash, $search, $device, $action) = @_;
  	my $name = $hash->{NAME};
  
  	Log3 $name, 5, $name.": <discoverCallback> device ".$device->friendlyName()." ".$device->UDN()." ".$action;

  	if($action eq "deviceAdded") {
    	MagentaTV_addedDevice($hash, $device);
  	} 
  	elsif($action eq "deviceRemoved") {
    	MagentaTV_removedDevice($hash, $device);
  	}
  	return undef;
}

sub MagentaTV_addedDevice {
  	my ($hash, $device) = @_;
  	my $name = $hash->{NAME};

    Log3 $hash, 5, $name.": <addedDevice> start ";  	
  
  	my $udn = $device->UDN();

  	#ignoreUDNs
  	return undef if(AttrVal($hash->{NAME}, "ignoreUDNs", "") =~ /$udn/);

  	#acceptedUDNs
  	my $acceptedUDNs = AttrVal($hash->{NAME}, "acceptedUDNs", "");
  	return undef if($acceptedUDNs ne "" && $acceptedUDNs !~ /$udn/);
    
  	my $foundDevice = 0;
  	my @allReceiver = MagentaTV_getAllReceiver($hash);
  	foreach my $ReceiverHash (@allReceiver) {
    	if($ReceiverHash->{UDN} eq $device->UDN()) {
      		$foundDevice = 1;
      		last;
    	}
  	}

  	if(!$foundDevice) {
  		# RECEIVER filtern, damit nur Receiver aus DeviceList angelegt werden 
  		if(exists($hash->{helper}{DeviceList}{deviceList})){
	  		foreach my $deviceList (@{$hash->{helper}{DeviceList}{deviceList}} ) {
				if(($deviceList->{deviceType} eq "0") && ($deviceList->{physicalDeviceId} eq substr($device->UDN(),29,12))){
					#ToDo: Name erweitern für mehrer ACCOUNTS
					my $uniqueDeviceName = "RECEIVER_".substr($device->UDN(),29,12);
					
					# Device in Fhem anlegen
					my $ret = CommandDefine(undef, "$uniqueDeviceName MagentaTV RECEIVER ".$device->UDN());
					
					if(defined($ret)){Log3 $name, 5, $name.": <addedDevice> CommandDefine with result: ".$ret};
					
					CommandAttr(undef,"$uniqueDeviceName alias ".$device->friendlyName());
					CommandAttr(undef,"$uniqueDeviceName room MagentaTV");
					CommandAttr(undef,"$uniqueDeviceName webCmd :");
					CommandAttr(undef,"$uniqueDeviceName devStateIcon offline:control_home:on online:control_on_off standby:control_standby\@red:on play:control_standby\@gray:off pause:control_standby\@gray:off");
		
					Log3 $name, 1, $name.": Created device $uniqueDeviceName for ".$device->friendlyName();
			
					#update list
					@allReceiver = MagentaTV_getAllReceiver($hash);
					last;
				}
	   		}
   		}
   		else{
   			Log3 $hash, 1, $name.": Create device RECEIVER_".substr($device->UDN(),29,12)." failed, because no DeviceList is loaded!";
   		}
  	}
  
  	foreach my $ReceiverHash (@allReceiver) {
    	if($ReceiverHash->{UDN} eq $device->UDN()) {
      		#device found, update data
      		$ReceiverHash->{helper}{device} = $device;
      		
      		#update device information
      		$ReceiverHash->{MAC} = substr($device->UDN(),29,12);
      		$ReceiverHash->{friendlyName} = $device->friendlyName();
      		$ReceiverHash->{modelName} = $device->modelName();
      		$ReceiverHash->{location} = $device->location();
      		$ReceiverHash->{deviceType} = $device->deviceType();
     		
 	  		if(exists($hash->{helper}{DeviceList}{deviceList})){
		  		foreach my $deviceList (@{$hash->{helper}{DeviceList}{deviceList}} ) {
					if(($deviceList->{deviceType} eq "0") && ($deviceList->{physicalDeviceId} eq substr($device->UDN(),29,12))){
						$ReceiverHash->{deviceId} = $deviceList->{deviceId};
						$ReceiverHash->{channelNamespace} = $deviceList->{channelNamespace};
						last;
					}
		   		}
	   		}
	   		else{
	   			Log3 $hash, 1, $name.": Update device ".$ReceiverHash->{NAME}." failed, because no DeviceList is loaded!";
	   		}
 	
  			# pairingID aus FUUID
      		$ReceiverHash->{pairingID} = uc(md5_hex($ReceiverHash->{FUUID}));
      		     		 
			#WakeOnLan
			my $description = $device->descriptionDocument();
			
			if($description =~ /<X_wakeOnLan>(.*?)<\/X_wakeOnLan>/){
				if($1 == 0){
					$ReceiverHash->{wakeOnLan} = "disabled";
				}
				else{
					$ReceiverHash->{wakeOnLan} = "enabled";
				}
			} 

     		RemoveInternalTimer($ReceiverHash, 'MagentaTV_renewSubscriptions');
			
			#callbacks für services
      		if(MagentaTV_GetUPnPService($ReceiverHash, "X-CTC_RemotePairing")) {
        		$ReceiverHash->{helper}{RemotePairing} = MagentaTV_GetUPnPService($ReceiverHash, "X-CTC_RemotePairing")->subscribe(sub { MagentaTV_subscriptionCallback($ReceiverHash, @_); });
     			$ReceiverHash->{sid_remotePairing} = $ReceiverHash->{helper}{RemotePairing}->SID if(AttrVal($ReceiverHash->{NAME}, "expert", 0));
	   			Log3 $hash, 4, $name.": <addedDevice> initial subscription service X-CTC_RemotePairing for ".$ReceiverHash->{NAME};  
      		}
			if(MagentaTV_GetUPnPService($ReceiverHash, "X-CTC_RemoteControl")) {
        		$ReceiverHash->{helper}{RemoteControl} = MagentaTV_GetUPnPService($ReceiverHash, "X-CTC_RemoteControl")->subscribe(sub { MagentaTV_subscriptionCallback($ReceiverHash, @_); });
    			$ReceiverHash->{sid_remoteControl} = $ReceiverHash->{helper}{RemoteControl}->SID if(AttrVal($ReceiverHash->{NAME}, "expert", 0));;
    			Log3 $hash, 4, $name.": <addedDevice> initial subscription service X-CTC_RemoteControl for ".$ReceiverHash->{NAME};  
      		}
			if(MagentaTV_GetUPnPService($ReceiverHash, "AVTransport")) {
        		$ReceiverHash->{helper}{AVTransport} = MagentaTV_GetUPnPService($ReceiverHash, "AVTransport")->subscribe(sub { MagentaTV_subscriptionCallback($ReceiverHash, @_); });
    			$ReceiverHash->{sid_AVTransport} = $ReceiverHash->{helper}{AVTransport}->SID if(AttrVal($ReceiverHash->{NAME}, "expert", 0));;
    			Log3 $hash, 4, $name.": <addedDevice> initial subscription service AVTransport for ".$ReceiverHash->{NAME};  
      		}
			if(MagentaTV_GetUPnPService($ReceiverHash, "ConnectionManager")) {
        		$ReceiverHash->{helper}{ConnectionManager} = MagentaTV_GetUPnPService($ReceiverHash, "ConnectionManager")->subscribe(sub { MagentaTV_subscriptionCallback($ReceiverHash, @_); });
    			$ReceiverHash->{sid_ConnectionManager} = $ReceiverHash->{helper}{ConnectionManager}->SID if(AttrVal($ReceiverHash->{NAME}, "expert", 0));;
    			Log3 $hash, 4, $name.": <addedDevice> initial subscription service ConnectionManager for ".$ReceiverHash->{NAME};  
      		}
			if(MagentaTV_GetUPnPService($ReceiverHash, "RenderingControl")) {
        		$ReceiverHash->{helper}{RenderingControl} = MagentaTV_GetUPnPService($ReceiverHash, "RenderingControl")->subscribe(sub { MagentaTV_subscriptionCallback($ReceiverHash, @_); });
    			$ReceiverHash->{sid_RenderingControl} = $ReceiverHash->{helper}{RenderingControl}->SID if(AttrVal($ReceiverHash->{NAME}, "expert", 0));;
    			Log3 $hash, 4, $name.": <addedDevice> initial subscription service RenderingControl for ".$ReceiverHash->{NAME};  
      		}
			if(MagentaTV_GetUPnPService($ReceiverHash, "X-CTC_OpenApp")) {
        		$ReceiverHash->{helper}{OpenApp} = MagentaTV_GetUPnPService($ReceiverHash, "X-CTC_OpenApp")->subscribe(sub { MagentaTV_subscriptionCallback($ReceiverHash, @_); });
    			$ReceiverHash->{sid_OpenApp} = $ReceiverHash->{helper}{OpenApp}->SID if(AttrVal($ReceiverHash->{NAME}, "expert", 0));;
    			Log3 $hash, 4, $name.": <addedDevice> initial subscription service X-CTC_OpenApp for ".$ReceiverHash->{NAME};  
      		}
      		
      		# renewSubscriptions starten
			$ReceiverHash->{helper}{keepalive} = AttrVal($ReceiverHash->{NAME}, "renewSubscription", 200); 
      		 
      		# BlockingKill RUNNING_PID exist - delete
      		if(exists($ReceiverHash->{helper}{RUNNING_PID})){
      			BlockingKill($ReceiverHash->{helper}{RUNNING_PID});
      			delete($ReceiverHash->{helper}{RUNNING_PID});
      		}
			InternalTimer(gettimeofday() + $ReceiverHash->{helper}{keepalive}, 'MagentaTV_renewSubscriptions', $ReceiverHash, 0);

			Log3 $hash, 3, $ReceiverHash->{NAME}.": current status during the Upnp search response - ".$ReceiverHash->{STATE};
			
			#wenn Receiver verbunden ist, aber eine neue Search gestartet wird, soll kein Statuswechsel und neues Pairing erfolgen
			if($ReceiverHash->{STATE} eq "offline"){			
				#set online
	        	readingsSingleUpdate($ReceiverHash,"state","online",1);
	        	Log3 $hash, 3, $ReceiverHash->{NAME}.": state of UPnP - online";
			
				# Pairing starten -> MagentaTV_pairingRequest($hash);
				readingsSingleUpdate($ReceiverHash,"pairing","initializing",1);
				InternalTimer(gettimeofday() + 20, 'MagentaTV_pairingRequest', $ReceiverHash, 0);
			}
			
			# EPG Kanalliste holen, immer wenn der Receiver gefunden wurde. 
			if(exists($ReceiverHash->{deviceId})){
				MagentaTV_getSender($ReceiverHash);
				#ToDo wie und wo refresh?
				# evtl. im HeardBit?
			}
			
			MagentaTV_TriggerDetailFn($ReceiverHash);
  		}
  	}
  
  	return undef;
}

sub MagentaTV_removedDevice {
  	my ($hash, $device) = @_;
  	my $name = $hash->{NAME};

    Log3 $name, 5, $name.": <removedDevice> start ";  	
  
  	my $ReceiverHash = MagentaTV_getHashByUDN($hash, $device->UDN());
  	return undef if(!defined($ReceiverHash));
	
	RemoveInternalTimer($ReceiverHash, 'MagentaTV_renewSubscriptions');
	if(exists($ReceiverHash->{helper}{RUNNING_PID})){
		BlockingKill($ReceiverHash->{helper}{RUNNING_PID});
		delete($ReceiverHash->{helper}{RUNNING_PID});
	}
	readingsSingleUpdate($ReceiverHash,"pairing","none", 1);
	readingsSingleUpdate($ReceiverHash,"state","offline", 1);
	MagentaTV_TriggerDetailFn($ReceiverHash);
	
	Log3 $ReceiverHash->{NAME}, 3, $ReceiverHash->{NAME}.": state of UPnP - offline";
	
	return undef;
}

sub MagentaTV_renewSubscriptions {
  	my ($hash) = @_;
  	my $name = $hash->{NAME};
  	
  	Log3 $hash, 4, $name.": <renewSubscription> try to renew subscriptions for services ";

  	if(!exists($hash->{helper}{RUNNING_PID})){
  		InternalTimer(gettimeofday() + $hash->{helper}{keepalive}, 'MagentaTV_renewSubscriptions', $hash, 0);
  		$hash->{helper}{RUNNING_PID} = BlockingCall('MagentaTV_renewSubscriptionBlocking', $hash->{NAME}, 'MagentaTV_renewSubscriptionBlockingDone', 10, 'MagentaTV_renewSubscriptionBlockingAborted', $hash) ;
  		Log3 $hash, 4, $name.": <renewSubscription> try to renew subscriptions for services with repeat in ".$hash->{helper}{keepalive}."s";
  	}
  	else{
   		Log3 $hash, 1, $name.": <renewSubscription> failed to call renewSubscriptionBlocking, check Log";
		
		RemoveInternalTimer($hash, 'MagentaTV_renewSubscriptions');
		readingsSingleUpdate($hash,"pairing","none", 1);
		readingsSingleUpdate($hash,"state","offline", 1);
		MagentaTV_TriggerDetailFn($hash);
		
		Log3 $name, 3, $name.": state of blocking - offline";
		
		my $hashAccount = MagentaTV_getHashOfAccount($hash);
		InternalTimer(gettimeofday() + 60, "MagentaTV_rescanNetwork", $hashAccount) ;
		
		Log3 $hash, 3, $name.': <renewSubscription> rescan networt will be start in 60s';
		
  	}
 
  	return undef;
}

sub MagentaTV_renewSubscriptionBlocking {
  	my ($string) = @_;
  	my ($name) = split("\\|", $string);
  	my $hash = $main::defs{$name};
  	my $err;
  	my $timeout = 0;
  	my $expired = 0;

#   	local $SIG{__WARN__} = sub {
#     	my ($called_from) = caller(0);
#     	my $wrn_text = shift;
#     	$wrn_text =~ m/^(.*?)\sat\s.*?$/;
#     	Log3 $name, 1, $name.": <renewSubscriptionBlocking> renewal of subscription failed: $1";
#     	#Log3 $name, 1, $name.": <renewSubscriptionBlocking> renewal of subscription failed: ".$called_from.", ".$wrn_text;
#   	};

  	Log3 $name, 5, $name.": <renewSubscriptionBlocking> try to renew subscriptions for services";  
 
  	# register callbacks again
  	eval {
  		local $SIG{__WARN__} = sub { die $_[0] };
  		
    	if(defined($hash->{helper}{RemotePairing})) {
    		$hash->{helper}{RemotePairing}->renew();
    		$timeout = $hash->{helper}{RemotePairing}->timeout();
    		$expired = $hash->{helper}{RemotePairing}->expired();
    	}
  	};
 	if($@) {
  		$err = $@;
  		$err =~ m/^(.*?)\sat\s.*?$/;
    	Log3 $name, 2, $name.": <renewSubscriptionBlocking> renewal of subscription service RemotePairing failed: $1 ";
    	return "$name|$1|undef|undef";
  	}
  
  	eval {
  		local $SIG{__WARN__} = sub { die $_[0] };
  		
    	if(defined($hash->{helper}{RemoteControl})) {
      		$hash->{helper}{RemoteControl}->renew();
       		$timeout = $hash->{helper}{RemoteControl}->timeout();
      		$expired = $hash->{helper}{RemoteControl}->expired();
    	}
  	};
 	if($@) {
  		$err = $@;
  		$err =~ m/^(.*?)\sat\s.*?$/;
    	Log3 $name, 2, $name.": <renewSubscriptionBlocking> renewal of subscription service RemoteControl failed: $1 ";
    	return "$name|$1|undef|undef";
  	}
  	
  	eval {
  		local $SIG{__WARN__} = sub { die $_[0] };
  		
    	if(defined($hash->{helper}{AVTransport})) {
      		$hash->{helper}{AVTransport}->renew();
       		$timeout = $hash->{helper}{AVTransport}->timeout();
      		$expired = $hash->{helper}{AVTransport}->expired();
    	}
  	};
 	if($@) {
  		$err = $@;
  		$err =~ m/^(.*?)\sat\s.*?$/;
    	Log3 $name, 2, $name.": <renewSubscriptionBlocking> renewal of subscription service AVTransport failed: $1 ";
    	return "$name|$1|undef|undef";
  	}

   	eval {
   		local $SIG{__WARN__} = sub { die $_[0] };
   		
    	if(defined($hash->{helper}{ConnectionManager})) {
      		$hash->{helper}{ConnectionManager}->renew();
      		$timeout = $hash->{helper}{ConnectionManager}->timeout();
      		$expired = $hash->{helper}{ConnectionManager}->expired();
    	}
  	};
 	if($@) {
  		$err = $@;
  		$err =~ m/^(.*?)\sat\s.*?$/;
    	Log3 $name, 2, $name.": <renewSubscriptionBlocking> renewal of subscription service ConnectionManager failed: $1 ";
    	return "$name|$1|undef|undef";
  	}

  	eval {
  		local $SIG{__WARN__} = sub { die $_[0] };
  		
    	if(defined($hash->{helper}{RenderingControl})) {
      		$hash->{helper}{RenderingControl}->renew();
      		$timeout = $hash->{helper}{RenderingControl}->timeout();
      		$expired = $hash->{helper}{RenderingControl}->expired();
    	}
  	};
 	if($@) {
  		$err = $@;
  		$err =~ m/^(.*?)\sat\s.*?$/;
    	Log3 $name, 2, $name.": <renewSubscriptionBlocking> renewal of subscription service RenderingControl failed: $1 ";
    	return "$name|$1|undef|undef";
  	}
  	
   	eval {
  		local $SIG{__WARN__} = sub { die $_[0] };
  		
    	if(defined($hash->{helper}{OpenApp})) {
      		$hash->{helper}{OpenApp}->renew();
      		$timeout = $hash->{helper}{OpenApp}->timeout();
      		$expired = $hash->{helper}{OpenApp}->expired();
    	}
  	};
 	if($@) {
  		$err = $@;
  		$err =~ m/^(.*?)\sat\s.*?$/;
    	Log3 $name, 2, $name.": <renewSubscriptionBlocking> renewal of subscription service X-CTC_OpenApp failed: $1 ";
    	return "$name|$1|undef|undef";
  	}
 	

  	Log3 $name, 5, $name.": <renewSubscriptionBlocking> finished to renew subscriptions for services ";  

  	return "$name|0|$timeout|$expired";
}

sub MagentaTV_renewSubscriptionBlockingAborted {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	Log3 $hash, 1, $name.': <renewSubscriptionBlockingAborted> subscription for services is aborted - possible reason for timeout: "No route to host"';
	
	delete($hash->{helper}{RUNNING_PID});
	
	RemoveInternalTimer($hash, 'MagentaTV_renewSubscriptions'); #wieder aktiviert
	readingsSingleUpdate($hash, "pairing", "none", 1);			#wieder aktiviert
	readingsSingleUpdate($hash,"state","offline", 1);
	MagentaTV_TriggerDetailFn($hash);
	
	Log3 $name, 3, $name.": state of network - offline";
	
	#ToDo was tun, nochmal probieren?
	#RECEIVER_AC6FBB7480FE: <renewSubscriptionBlocking> renewal of subscription failed: Carp, Renewal of subscription failed with error: 500 Can't connect to 192.168.2.22:8081 (Connection timed out) at /opt/fhem/fhem.sonos/FHEM/78_MagentaTV.pm line 2855.
	
	#UPnP Suche nochmal starten, aber mit UDN?
	#oder einfach suche nochmals starten?
	#habe mich für rescanNetwork entschieden mit kleiner Verzögerung
	my $hashAccount = MagentaTV_getHashOfAccount($hash);
	InternalTimer(gettimeofday() + 60, "MagentaTV_rescanNetwork", $hashAccount) ;

	Log3 $hash, 3, $name.': <renewSubscriptionBlockingAborted> rescan networt will be start in 60s';
	
	return undef;
}

sub MagentaTV_renewSubscriptionBlockingDone {
	my ($string) = @_;

  	my ($name, $err, $timeout, $expired) = split("\\|", $string);
  	my $hash = $main::defs{$name};
	
	delete($hash->{helper}{RUNNING_PID});
	
	Log3 $name, 4, $name.": <renewSubscriptionBlockingDone> Error: ".$err." Timeout: ".$timeout." Expired: ".$expired;
  	
	if($err ne "0"){
		Log3 $hash, 1, $name.": <renewSubscriptionBlockingDone> renewal of subscription failed: ".$err;
		
		RemoveInternalTimer($hash, 'MagentaTV_renewSubscriptions');
		readingsSingleUpdate($hash,"pairing","none", 1);
		readingsSingleUpdate($hash,"state","offline", 1);
		MagentaTV_TriggerDetailFn($hash);
		
		Log3 $name, 3, $name.": state of network - offline";
		#ToDo was tun?
		# 412 Precondition Failed detected -> Rescan Network?
		#habe mich für rescanNetwork entschieden mit kleiner Verzögerung
		my $hashAccount = MagentaTV_getHashOfAccount($hash);
		InternalTimer(gettimeofday() + 60, "MagentaTV_rescanNetwork", $hashAccount) ;
	
		Log3 $hash, 3, $name.': <renewSubscriptionBlockingDone> rescan networt will be start in 60s';
		
		return undef;
	}	
	
  	Log3 $hash, 5, $name.": <renewSubscriptionBlockingDone> finished to renew subscriptions for services with repeat in ".$hash->{helper}{keepalive}."s";

	return undef;
}

# Sockets ######################################################################

sub MagentaTV_newChash {
  my ($hash,$socket,$chash) = @_;

  $chash->{TYPE}  = $hash->{TYPE};
  $chash->{SUBTYPE}  = "UPnPSocket";
  $chash->{STATE}   = "open"; 

  $chash->{NR}    = $devcount++;

  $chash->{phash} = $hash;
  $chash->{PNAME} = $hash->{NAME};

  $chash->{CD}    = $socket;
  $chash->{FD}    = $socket->fileno();

  $chash->{PORT}  = $socket->sockport if( $socket->sockport );

  $chash->{TEMPORARY} = 1;
  $attr{$chash->{NAME}}{room} = 'hidden';

  $defs{$chash->{NAME}}       = $chash;
  $selectlist{$chash->{NAME}} = $chash;
}

sub MagentaTV_addSocketsToMainloop {
  my ($hash) = @_;
  my $name ;
  my @sockets = $hash->{helper}{controlpoint}->sockets();
  
  #check if new sockets need to be added to mainloop
  foreach my $s (@sockets) {
    #create chash and add to selectlist
    if( $s->sockport ) {
    	$name  = "UPnPSocket_".$hash->{NAME}."_".$s->sockport;
    }
    else {
    	$name  = "UPnPSocket_".$hash->{NAME};
    }
    
    Log3 $name, 5, $name.": <addSocketsToMainloop> add ".$s;
    
  	my $chash = MagentaTV_newChash($hash, $s, {NAME => $name});
  }
  
  return undef;
}

# Get Service ##################################################################

sub MagentaTV_GetUPnPService {
  	my ($hash, $service) = @_;
  	my $name = $hash->{NAME};
  
  	Log3 $name, 5, $name.": <GetUPnPService> start ";
  
  	my $upnpService;
  	#ToDo defined device?
  	foreach my $srvc ($hash->{helper}{device}->services) {
    	my @srvcParts = split(":", $srvc->serviceType);
    	my $serviceName = $srvcParts[-2];
    	if($serviceName eq $service) {
      		Log3 $name, 5, $name.": <GetUPnPService> $service: ".$srvc->serviceType." found. OK.";
      		$upnpService = $srvc;
    	}
  	}
  
  	if(!defined($upnpService)) {
    	Log3 $name, 1, $name.": $service unknown";
    	return undef;
  	}
  
  	return $upnpService;
}

# Subscription Callback ########################################################
 
sub MagentaTV_subscriptionCallback {
  	my ($hash, $service, %properties) = @_;
  	my $name = $hash->{NAME};
	my $data;  
  	my $serviceType = $service->serviceType;
  	
  	my $deviceID = "";
  	my $pairingCheck = "";
  	my $programStart;
  	my $channelId;
  	my $channelIdHash;
  	my $mediaCodeHash;
  	
  	Log3 $name, 5, $name.": <subscriptionCallback> serviceID $serviceType received event";#.Dumper(%properties);
  	
  	$hash->{helper}{subscriptionCallback} = \%properties;
  	
	# hash vom ACCOUNT für userID
	my $hashAccount = MagentaTV_getHashOfAccount($hash);

  	readingsBeginUpdate($hash); 	
  	
 	while (my ($key, $val) = each %properties) {
    	
    	Log3 $name, 5, $name.": <subscriptionCallback> Property ${key}'s value is $val";
    	
    	$key = decode_entities($key);
    	$val = decode_entities($val);
    	
    	if($key eq 'STB_Mac'){
    		my $STB_Mac = $val;
    		# ToDo wozu?
    	}
    	elsif($key eq 'STB_playContent'){
    		$data = decode_json($val);
			
			if(defined($data)){
				my $newPlayModeVal = $data->{"new_play_mode"};
				my $playBackStateVal = $data->{"playBackState"};
				readingsBulkUpdate($hash, "newPlayMode", $newPlayMode{$newPlayModeVal}, 1);
				readingsBulkUpdate($hash, "playBackState", $playBackState{$playBackStateVal}, 1);
				readingsBulkUpdate($hash, "mediaType", $data->{"mediaType"}, 1);
				#readingsBulkUpdate($hash, "trickPlayMode", $data->{"trickPlayMode"}, 1);
				readingsBulkUpdate($hash, "mediaCode", $data->{"mediaCode"}, 1);

				if(defined($data->{"mediaCode"})){
					if(($data->{"mediaCode"} eq "4806") || ($data->{"mediaCode"} eq "4809")){
						#Hack für mediaCode 4806, 4809. Für diesen Mediacode ist nichts hinterlegt, deshalb umgeleitet auf:
						readingsBulkUpdate($hash, "channelName", "Sender ist nicht gebucht", 1);
						readingsBulkUpdate($hash, "channelCode", 115, 1);
						readingsBulkUpdate($hash, "chanNo", "", 1);
						readingsBulkUpdate($hash, "channel", "", 1);
						readingsBulkUpdate($hash, "favorite", 0, 1);
						
						$channelId = 115;
					}
					else{
						$mediaCodeHash = MagentaTV_mediaCode2hash($hash,$data->{"mediaCode"});
	
						readingsBulkUpdate($hash, "channelName", $mediaCodeHash->{channelName}, 1);
						readingsBulkUpdate($hash, "channelCode", $mediaCodeHash->{contentId}, 1);
						readingsBulkUpdate($hash, "chanNo", $mediaCodeHash->{chanNo}, 1);
						readingsBulkUpdate($hash, "channel", $mediaCodeHash->{channel}, 1);
						readingsBulkUpdate($hash, "favorite", $mediaCodeHash->{favorite}, 1);
						
						# für MagentaTV_getPlayBillContextEx($hash,$channelId);
						$channelId = $mediaCodeHash->{contentId};
					}
				}
				
				if(defined($newPlayModeVal)){
					if($newPlayModeVal == 2 || $newPlayModeVal == 3 || $newPlayModeVal == 4 || $newPlayModeVal == 5 || $newPlayModeVal == 20){
						readingsBulkUpdate($hash, "state", "play", 1);
						if($newPlayModeVal == 3){
							Log3 $name, 3, $name.": state of callback - play (FF/RW)";
						}
						elsif($newPlayModeVal == 4){
							Log3 $name, 3, $name.": state of callback - play (Multicast)";
						}
						elsif($newPlayModeVal == 5){
							Log3 $name, 3, $name.": state of callback - play (Unicast)";
						}
						elsif($newPlayModeVal == 20){
							Log3 $name, 3, $name.": state of callback - play (Buffering)";
						}
						else{
							Log3 $name, 3, $name.": state of callback - play";
						}
					}
					elsif($newPlayModeVal == 1 ){
						readingsBulkUpdate($hash, "state", "pause", 1);
						Log3 $name, 3, $name.": state of callback - pause";
					}
					elsif($newPlayModeVal == 0){
						readingsBulkUpdate($hash, "state", "standby", 1);
						Log3 $name, 3, $name.": state of callback - standby";
					}
				}
				#	0 => "STOP",
				# 	1 => "PAUSE",
				# 	2 => "PLAY",
				# 	3 => "<<PLAY>>",
				# 	4 => "PLAY Multicast",
				# 	5 => "PLAY Unicast",
				# 	20 => "BUFFERING"
				#MagentaTV_TriggerDetailFn($hash);
			}
    	}
    	elsif($key eq 'STB_EitChanged'){
    		$data = decode_json($val);
    		
			if(defined($data)){
				readingsBulkUpdate($hash, "channelCode", $data->{"channel_code"}, 1);
				readingsBulkUpdate($hash, "chanNo", $data->{"channel_num"}, 1);

				if(defined($data->{"channel_code"})){
					$channelIdHash = MagentaTV_channelId2hash($hash,$data->{"channel_code"});
					
					readingsBulkUpdate($hash, "channel", $channelIdHash->{channel}, 1);
					readingsBulkUpdate($hash, "channelName", $channelIdHash->{channelName}, 1);
					readingsBulkUpdate($hash, "mediaCode", $channelIdHash->{mediaId}, 1);
					readingsBulkUpdate($hash, "favorite", $channelIdHash->{favorite}, 1);
					
					# für MagentaTV_getPlayBillContextEx($hash,$data->{"channel_code"},$programStart); 
					$programStart 	= $data->{"program_info"}[0]{"start_time"};   #$data->{"program_info"};  Konnte auch angelegt, aber leer sein.
					$channelId		= $data->{"channel_code"};
				}
				
				# PrograminfoReadings
				if(AttrVal($name,"PrograminfoReadings",0)){
					if(defined($programStart)){
						readingsBulkUpdate($hash, "currentProgramDuration", substr($data->{"program_info"}[0]{"duration"},0,5), 1);
						readingsBulkUpdate($hash, "currentProgramStart", MagentaTV_timeCalc($data->{"program_info"}[0]{"start_time"}), 1);
						readingsBulkUpdate($hash, "currentProgramTime", MagentaTV_timeCalc($data->{"program_info"}[0]{"start_time"},$data->{"program_info"}[0]{"duration"}), 1);
						readingsBulkUpdate($hash, "currentProgramStatus", $runningStatus{$data->{"program_info"}[0]{"running_status"}}, 1);
						readingsBulkUpdate($hash, "currentProgramTitle", encode('utf-8', $data->{"program_info"}[0]{"short_event"}[0]{"event_name"}), 1);
						readingsBulkUpdate($hash, "currentProgramGenre", encode('utf-8', $data->{"program_info"}[0]{"short_event"}[0]{"text_char"}), 1);
	
						readingsBulkUpdate($hash, "nextProgramDuration", substr($data->{"program_info"}[1]{"duration"},0,5), 1);
						readingsBulkUpdate($hash, "nextProgramStart", MagentaTV_timeCalc($data->{"program_info"}[1]{"start_time"}), 1);
						readingsBulkUpdate($hash, "nextProgramTime", MagentaTV_timeCalc($data->{"program_info"}[1]{"start_time"},$data->{"program_info"}[1]{"duration"}), 1);
						readingsBulkUpdate($hash, "nextProgramStatus", $runningStatus{$data->{"program_info"}[1]{"running_status"}}, 1);
						readingsBulkUpdate($hash, "nextProgramTitle", encode('utf-8', $data->{"program_info"}[1]{"short_event"}[0]{"event_name"}), 1);
						readingsBulkUpdate($hash, "nextProgramGenre", encode('utf-8', $data->{"program_info"}[1]{"short_event"}[0]{"text_char"}), 1);	
					}
				}
			}
    	}
     	elsif($key eq 'uniqueDeviceID'){
    		$deviceID = $val;
    	}
    	elsif($key eq 'messageBody'){
    		$pairingCheck = $val;
    		$pairingCheck =~ s/X-pairingCheck://;
    		readingsBulkUpdate($hash, "pairingCheck", $pairingCheck, 1);
    	}
    	else{
    		#Log später wieder auf 4! Vieleicht habe ich Events übersehen.
    		#Nein, zumindest keine aussagefähigen - MR400 senden etwas mehr, aber ohne Inhaltsänderung.
    		Log3 $name, 4, $name.": <subscriptionCallback> Property ${key}'s value is $val and was not decode ";
    	}
    }

    readingsEndUpdate($hash, 1);
 	
 	#erst hier Content abfragen, da sonst readingsSingleUpdate Probleme macht
	if(defined($channelId)){
		MagentaTV_getPlayBillContextEx($hash,$channelId,$programStart); 
	}
    
    #detailFn refresh
    MagentaTV_TriggerDetailFn($hash);

	# Prüfen ist pairingCheck neu ist und die uniqueID die Gleiche wie gesendet
	# ToDo braucht es noch RUN?
    if(($hash->{helper}{Pairing}{RUN}) && ($pairingCheck) && ($deviceID eq $hash->{pairingID})){
    	MagentaTV_pairingCheck($hash); # Pairing Verifizieren
    }
    
  	return undef;
}



# Find Hash's ##################################################################

sub MagentaTV_getAllReceiver {
  	my ($hash) = @_;
  	my $name = $hash->{NAME};
  	
    Log3 $name, 5, $name.": <getAllReceiver> start ";  	
  	
  	my @Devices = ();
    
  	foreach my $fhem_dev (sort keys %main::defs) {
    	push @Devices, $main::defs{$fhem_dev} if($main::defs{$fhem_dev}{TYPE} eq 'MagentaTV' && $main::defs{$fhem_dev}{SUBTYPE} eq 'RECEIVER');
  	}
		
  	return @Devices;
}

sub MagentaTV_getAllUPnPSockets {
  	my ($hash) = @_;
  	my $name = $hash->{NAME};
  	
    Log3 $name, 5, $name.": <getAllUPnPSockets> start ";  	
  	
  	my @Devices = ();
    
  	foreach my $fhem_dev (sort keys %main::defs) {
    	push @Devices, $main::defs{$fhem_dev} if($main::defs{$fhem_dev}{TYPE} eq 'MagentaTV' && $main::defs{$fhem_dev}{SUBTYPE} eq 'UPnPSocket');
  	}
		
  	return @Devices;
}

sub MagentaTV_getHashByUDN {
  	my ($hash, $udn) = @_;
  	my $name = $hash->{NAME};

    Log3 $name, 5, $name.": <getHashByUDN> start ";  	
  	
  	foreach my $fhem_dev (sort keys %main::defs) {
    	return $main::defs{$fhem_dev} if($main::defs{$fhem_dev}{TYPE} eq 'MagentaTV' && $main::defs{$fhem_dev}{SUBTYPE} ne 'ACCOUNT' && $main::defs{$fhem_dev}{SUBTYPE} ne 'UPnPSocket' && $main::defs{$fhem_dev}{UDN} eq $udn);
  	}
		
  	return undef;
}

sub MagentaTV_getHashOfAccount {
  	my ($hash) = @_;
  	my $name = $hash->{NAME};

    Log3 $name, 5, $name.": <getHashOfAccount> start ";  	
  	
  	foreach my $fhem_dev (sort keys %main::defs) {
    	return $main::defs{$fhem_dev} if($main::defs{$fhem_dev}{TYPE} eq 'MagentaTV' && $main::defs{$fhem_dev}{SUBTYPE} eq 'ACCOUNT');# && $main::defs{$fhem_dev}{UDN} eq "0" && $main::defs{$fhem_dev}{UDN} ne "-1"));
  	}
		
  	return undef;
}


# Password Crypt ###############################################################

sub MagentaTV_encrypt {
  	my ($decoded) = @_;
  	my $key = getUniqueId();
  	my $encoded;

  	return $decoded if( $decoded =~ /crypt:/ );

  	for my $char (split //, $decoded) {
    	my $encode = chop($key);
    	$encoded .= sprintf("%.2x",ord($char)^ord($encode));
    	$key = $encode.$key;
  	}

  	return 'crypt:'.$encoded;
}

sub MagentaTV_decrypt {
  	my ($encoded) = @_;
  	my $key = getUniqueId();
  	my $decoded;

  	return $encoded if( $encoded !~ /crypt:/ );
  
  	$encoded = $1 if( $encoded =~ /crypt:(.*)/ );

  	for my $char (map { pack('C', hex($_)) } ($encoded =~ /(..)/g)) {
    	my $decode = chop($key);
    	$decoded .= chr(ord($char)^ord($decode));
    	$key = $decode.$key;
  	}

  	return $decoded;
}

# send Key Sequence ############################################################

sub MagentaTV_sendKeys {
  	my ($hash, $keys) = @_;
  	my $name = $hash->{NAME};
 
 	Log3 $name, 5, $name.": <sendKeys> start";
 
 	my @keyList = split(/ /,$keys);
 	
 	my $i;
 	for($i=0;$i<@keyList;++$i) {
   		EntertainTV_RemoteKey($hash, $keyList[$i]);
	} 
 	
  	return undef;
}


# rescan Network ###############################################################

sub MagentaTV_rescanNetwork {
  	my ($hash) = @_;
  	my $name = $hash->{NAME};
 
 	Log3 $name, 5, $name.": <rescanNetwork> start";
 
	MagentaTV_StopControlPoint($hash);
	if(MagentaTV_setupControlpoint($hash)){
		MagentaTV_startSearch($hash);
	}  	

  	#RescanNetwork nach x min wieder starten, wenn gewollt
  	InternalTimer(gettimeofday() + (AttrVal($name,"RescanNetworkInterval",60) * 60), "MagentaTV_rescanNetwork", $hash) if(AttrVal($name,"RescanNetworkInterval",0));
 	
  	return undef;
}


# Senderwechsel ################################################################

sub MagentaTV_changeChannel {
  	my ($hash, $channel) = @_;
  	my $name = $hash->{NAME};
  	
  	Log3 $name, 5, $name.": <changeChannel> start - channel: ".$channel;
  	
	foreach my $index(@{$hash->{helper}{senderNameList}}){
		if($index->{channel} eq $channel){
			#Stop Transport
			MagentaTV_Stop($hash);
			#Set URI
			MagentaTV_SetAVTransportURI($hash, $index->{contentId}, $index->{mediaId});
			#Start Transport
			MagentaTV_Play($hash);
			return 1;
		}
	}
 	
  	return undef;  	
}

# mediaCode2hash ##########################################################

sub MagentaTV_mediaCode2hash {
  	my ($hash, $mediaId) = @_;
  	my $name = $hash->{NAME};
  	
  	Log3 $name, 5, $name.": <mediaCode2hash> start";

	foreach my $index(@{$hash->{helper}{senderNameList}}){
		if($index->{mediaId} eq $mediaId){
			return $index;
		}
	}
	return undef;
}

# channelId2hash ###############################################################

sub MagentaTV_channelId2hash {
  	my ($hash, $contentId) = @_;
  	my $name = $hash->{NAME};
  	
  	Log3 $name, 5, $name.": <channelId2hash> start";

	foreach my $index(@{$hash->{helper}{senderNameList}}){
		if($index->{contentId} eq $contentId){
			return $index;
		}
	}
	return undef;
}

# chanNo2channel ############################################################

sub MagentaTV_chanNo2channel {
  	my ($hash, $chanNo) = @_;
  	my $name = $hash->{NAME};
  	
  	Log3 $name, 5, $name.": <chanNo2channel> start";

	foreach my $index(@{$hash->{helper}{senderNameList}}){
		if($index->{chanNo} eq $chanNo){
			return $index->{channel};
		}
	}
	return undef;
}

# senderName2channel #############################################################

sub MagentaTV_senderName2channel {
  	my ($hash, $senderName) = @_;
  	my $name = $hash->{NAME};
  	
  	Log3 $name, 5, $name.": <senderName2channel> start";
	
	my $listName;
	foreach my $index(@{$hash->{helper}{senderNameList}}){
		$listName = $index->{channelName}." ".$index->{format};
		#$listName =~ s/&nbsp;/ /g;
		if($listName eq $senderName){
			return $index->{channel};
		}
	}
	return undef;
}

# pictures #####################################################################

sub MagentaTV_pictures {
  	my ($hash, $array) = @_;
  	my $name = $hash->{NAME};
  	
  	Log3 $name, 5, $name.": <pictures> start";
	
	foreach my $index(@{$array}){
		if($index->{imageType} eq "17"){
			return ($index->{imageType},$index->{href});
		}
	}
	foreach my $index(@{$array}){
		if($index->{imageType} eq "20"){
			return ($index->{imageType},$index->{href});
		}
	}
	return (undef,undef);
}

# audioType ####################################################################

sub MagentaTV_audioType {
  	my ($hash, $array) = @_;
  	my $name = $hash->{NAME};
  	my $data;
  	
  	Log3 $name, 5, $name.": <audioType> start";
  	
  	$array = decode_json($array);
	$hash->{helper}{audioType} = $array;
	#Debug(Dumper($array));
	
	foreach my $index(@{$array}){
		if(defined($index->{language}) && defined($index->{coding}) && defined($index->{mix})){
			if(($index->{language} eq "deu") && ($index->{coding} eq "ac3")){
				return ($index->{mix},$index->{coding});
			}
		}
	}
	foreach my $index(@{$array}){
		if(defined($index->{language}) && !defined($index->{coding}) && defined($index->{mix})){
			if($index->{language} eq "deu"){
				return ($index->{mix},undef);
			}
		}
	}
	return (undef,undef);
}
# Sendernamen ##################################################################

sub MagentaTV_getSender {
	my ($hash) = @_;
  	my $name = $hash->{NAME};

	Log3 $name, 5, $name.": <MagentaTV_getSender> start";

	MagentaTV_getCustomChanNo($hash);
	MagentaTV_getFavorite($hash);
	MagentaTV_getSenderNameList($hash);
	
	#Timer ????
	
	return undef;
}

sub MagentaTV_getSenderNameList {
	my ($hash) = @_;
  	my $name = $hash->{NAME};

	Log3 $name, 5, $name.": <getSenderNameList> start";

    # hash vom ACCOUNT 
  	my $hashAccount = MagentaTV_getHashOfAccount($hash);
	
	my $channelName;
	my $contentId;
	my $chanNo;
	my $channel;
	my $mediaId;
	my $format;
	my $logo;
	my $favorite;

	my %senderNameListHash;
	my @senderNameList;
	my $customChanNo;
	my $favoritelist;
	my $favoritCount = 0;
	my $senderNameListRet;
	my $chanNoListRet;
	
  	foreach my $item( @{$hashAccount->{helper}{channellist}} ){
		$contentId 	 = $item->{contentId};
		$chanNo 	 = $item->{chanNo};
		$channel 	 = $item->{chanNo};
		$channelName = $item->{name};
		#Hack für zu langen Namen bei Magenta Sport
		if($contentId == 620){$channelName = "Livesendung_MagentaSport"};	
		
		#nach definition mediaID ermitteln im Array
		$mediaId = "undef";
		$format = "";
		$favorite = 0;
		foreach my $physicalChannelsItem( @{$item->{physicalChannels}} ){
			#definition = 0 ->SD
			#definition = 1 ->HD
			#definition = 2 ->UHD
			if(exists($physicalChannelsItem->{definition})){
				if(($physicalChannelsItem->{definition} eq "0") && ($format ne "HD") && ($format ne "UHD")){
					$format = "SD";
					$mediaId = $physicalChannelsItem->{mediaId};
				}
				if(($physicalChannelsItem->{definition} eq "1") && ($format ne "UHD")){
					$format = "HD";
					$mediaId = $physicalChannelsItem->{mediaId};
				}
				if($physicalChannelsItem->{definition} eq "2"){
					$format = "UHD";
					$mediaId = $physicalChannelsItem->{mediaId};
				}
			}		
		}
		#keine definition = abbruch		
		#if($mediaId eq ""){next};
		
		#ToDo UHD raus beim MR400
		if((!exists($hash->{enable4K})) && ($format eq "UHD")){next};

		#Senderlogo
		$logo = "";
		foreach my $pictureItem( @{$item->{pictures}} ){
			if($pictureItem->{imageType} == 15){
				$logo = $pictureItem->{href};
			}
		}

		# Abgleich mit Listen

		#Favorites
		if(defined($hash->{helper}{favoritelist})){
			foreach my $favoritelistItem( @{$hash->{helper}{favoritelist}} ){ 
				if($favoritelistItem->{id} eq $contentId){
					$favorite = 1;
					$favoritCount++;
					last; #Abbruch nach 1. Auftreten
				}
			}
		}
		
		#nach Liste der sichtbaren Sender
		if(defined($hash->{helper}{customChanNo})){
			foreach my $customChanNoItem( @{$hash->{helper}{customChanNo}} ){
				if($customChanNoItem->{key} eq $contentId){
					$chanNo = $customChanNoItem->{value};
					last; #Abbruch nach 1. Auftreten
				}
			}
		}
		
		if($chanNo < 0){next}; #lässt nur die sichtbaren Sender übrig
		
		$channelName =~ s/\(//g;			# Klammern löschen
		$channelName =~ s/\)//g;			# Klammern löschen
		$channelName =~ s/ UHD//g;			# Wenn im Namen schon UHD vorkommt
		$channelName = encode('utf-8', $channelName);
		
		#hier hash im hash speichern mit 
		$senderNameListHash{$chanNo}{channelName} = $channelName;
		$senderNameListHash{$chanNo}{mediaId} = $mediaId;
		$senderNameListHash{$chanNo}{contentId} = $contentId;
		$senderNameListHash{$chanNo}{chanNo} = $chanNo;
		$senderNameListHash{$chanNo}{channel} = $channel;
		$senderNameListHash{$chanNo}{format} = $format;
		$senderNameListHash{$chanNo}{logo} = $logo;
		$senderNameListHash{$chanNo}{favorite} = $favorite;
	}

	foreach my $key (sort{$a<=>$b} keys %senderNameListHash) {
		my $rec = {}; 
		$rec->{channelName} = $senderNameListHash{$key}{channelName}; 
		$rec->{mediaId} = $senderNameListHash{$key}{mediaId};
		$rec->{contentId} = $senderNameListHash{$key}{contentId};
		$rec->{format} = $senderNameListHash{$key}{format};
		$rec->{logo} = $senderNameListHash{$key}{logo};
		$rec->{favorite} = $senderNameListHash{$key}{favorite};
		$rec->{chanNo} = $senderNameListHash{$key}{chanNo};
		$rec->{channel} = $senderNameListHash{$key}{channel};
		push @senderNameList, $rec; 
				
		if((AttrVal($name,"SenderListType","custom") eq "favorit") && ($senderNameListHash{$key}{favorite} == 0)){next};
			
		$senderNameListRet .= $senderNameListHash{$key}{channelName}." ".$senderNameListHash{$key}{format}.",";
		$chanNoListRet .= $senderNameListHash{$key}{chanNo}.",";
	}
	$chanNoListRet 		=~ s/,$//g; #letztes Komma wieder weg
	$senderNameListRet 	=~ s/,$//g; #letztes Komma wieder weg
	$senderNameListRet 	=~ s/\s+/&nbsp;/g;		# Leerzeichen ersetzen s/\s+/&nbsp;;/g;
		
	$hash->{helper}{senderNameList} = \@senderNameList;
	$hash->{helper}{senderNameListSet} = $senderNameListRet;
	$hash->{helper}{chanNoListSet} = $chanNoListRet;
	$hash->{channelsVisible} = scalar(@senderNameList);
	$hash->{channelsFavorit} = $favoritCount;

}

# wake over LAN ################################################################

sub MagentaTV_wol {
    my ($name,$mac_addr) = @_;
    my $address = '255.255.255.255';
    my $port = 9;

	Log3 $name, 5, $name.": <wol> start";

    my $sock = new IO::Socket::INET( Proto => 'udp' )
      or die "socket : $!";
    die "Can't create WOL socket" if ( !$sock );

    my $ip_addr = inet_aton($address);
    my $sock_addr = sockaddr_in( $port, $ip_addr );
    $mac_addr =~ s/://g;
    my $packet =
      pack( 'C6H*', 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, $mac_addr x 16 );

    setsockopt( $sock, SOL_SOCKET, SO_BROADCAST, 1 )
      or die "setsockopt : $!";
	
	Log3 $name, 3, $name.": Waking up by sending Wake-On-Lan magic package to $mac_addr";
	
    send( $sock, $packet, 0, $sock_addr ) or die "send : $!";
    close($sock);

    return;
}

# Funktionen ###################################################################

sub MagentaTV_timeCalc {
	my ($startTime, $duration) = @_;
	
	$startTime =~ s/\//-/g;
	$startTime = str2time($startTime, 'GMT');
	my $result = POSIX::strftime("%a. %d.%m.%Y | %H:%M",localtime($startTime));
	
	if(defined($duration)){
		#$duration = str2time("1970-01-01 ".$duration, 'GMT');
		#$result .= POSIX::strftime(" - %H:%M",localtime($startTime + $duration));
        my ($durHours,$durMinutes) = split /:/, $duration;
        my $durationInSeconds = int($durHours)*3600 + int($durMinutes)*60;
        my $endTime = $startTime + $durationInSeconds;
        $result .= POSIX::strftime(" - %H:%M",localtime($endTime));
	}
	
	return $result;
}

sub MagentaTV_timePrint {
	my ($startTime, $endTime) = @_;
	
	$startTime = str2time($startTime);
	$endTime = str2time($endTime);
	my $result = POSIX::strftime("%a. %d.%m.%Y | %H:%M",localtime($startTime));
	$result .= POSIX::strftime(" - %H:%M",localtime($endTime));
	$result .= POSIX::strftime(" | %H:%M",gmtime($endTime - $startTime));
	
	return $result;
}

sub MagentaTV_UUID {
	my ($hash) = @_;
  	my $fuuid = $hash->{FUUID};
 
	# xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
	my $uuid = substr($fuuid,0,36);
	substr($uuid,14,1) = "4";

	return $uuid;
}

################################################################################

# Eval-Rückgabewert für erfolgreiches
# Laden des Moduls
1;


# Beginn der Commandref ########################################################

=pod

=encoding utf8

=item device
=item summary Controlling of Telekom MagentaTV Receivers
=item summary_DE Steuerung von Telekom MagentaTV Receivern

=begin html

<a name="MagentaTV" id="MagentaTV"></a>
<h3>
	MagentaTV
</h3>
<ul>
  	MagentaTV finds all MagentaTV receivers automatically, controls them and displays various information.<br />
  	<br />
    <b>Note:</b> The following libraries are necessary for this module:
	<ul>
		<li>Digest::MD5</li> 
		<li>HTML::Entities</li> 
		<li>JSON</li> 
		<li>HttpUtils</li> 
		<li>Blocking</li> 
		<li>UPnP::ControlPoint</li> 
		<li>Date::Parse</li> 
		<li>Encode</li>
		<br />
	</ul>
  	<a name="MagentaTV_Define" id="MagentaTV_Define"></a><b>Define</b>
  	<ul>
    	<code>define &lt;name&gt; MagentaTV username password</code><br />
    	<br />
    	Example: <code>define Entertain MagentaTV xxx@t-online.de xxxxxxx</code><br />
  	</ul><br />
  	<b>Note</b>
  	<ul>
    	Please see the german help for more information, many thanks.<br />
  	</ul>  
</ul>

=end html

=begin html_DE

<a name="MagentaTV" id="MagentaTV"></a>
<h3>
	MagentaTV
</h3>
<ul>
  	MagentaTV findet automatisch alle MagentaTV Receiver, kann diese steuern und zeigt Programminformationen an.<br />
  	<br />
  	Es wird für die Darstellung der Programinformationen ein ständig aktiver Telekom Account benötigt. Dieser Client wird als 'Fhem' (Browser Type MACWEBTV) in der DeviceList angezeigt. Es sind nur bis zu 5 Clients möglich. Damit könnte es zu Schwierigkeiten kommen, sofern die Anzahl an Clients schon ausgeschöpft ist.<br />
  	<br />
    <b>Hinweis:</b> Folgende Libraries sind notwendig für dieses Modul:
	<ul>
		<li>Digest::MD5</li>
		<li>HTML::Entities</li>
		<li>JSON</li>
		<li>HttpUtils</li>
		<li>Blocking</li>
		<li>UPnP::ControlPoint</li>
		<li>Date::Parse</li>
		<li>Encode</li>
		<br />
	</ul>
  	<a name="MagentaTV_Define" id="MagentaTV_Define"></a><b>Define</b>
  	<ul>
    	<code>define &lt;name&gt; MagentaTV Benutzername Password</code><br />
    	<br />
    	Example: <code>define MagentaTV MagentaTV xxx@t-online.de xxxxxxx</code><br />
    	<br />
    	Nach ca. 2 Minuten sollten alle Receiver gefunden und unter "MagentaTV" gelistet sein.
  	</ul><br />
  	<a name="MagentaTV_Set" id="MagentaTV_Set"></a><b>Set</b>
	<ul>
	    ACCOUNT<br />
		<ul>
			<li><b>Logout</b><br />
	  			Logout des Telekom Accounts.
			</li>
			<li><b>RefreshCredentials</b><br />
	  			Erneuert das Login zum Telekom Account.
			</li>
			<li><b>RescanNetwork</b><br />
	  			Startet die Suche nach Receivern erneut.
			</li>
		</ul>
	</ul><br />
  	<ul>
	    RECEIVER<br />
		<ul>
			<li><b>on</b><br />
	  			Schaltet den Receiver ein, sofern er sich im Standby befindet.<br />
	  			MR401: Im Modus "Ruhezustand" wird der Receiver per WOL aktiviert und setzt sich in den Standby Modus. Dann kann er eingeschaltet werden.<br />
	  			Die Bedingungen sind:<br />
	  			<ul TYPE=disc>
					<li>Receiver muss im Modus "Ruhezustand" (MR401) sein. Der Hilfetext dazu sagt auch aus, das der Receiver aufgeweckt werden kann.</li> 
					<li>Nachdem MagentaTV ihn, nach einem manuellen Einschalten wieder gefunden Hat, sollte das Internal "wakeOnLan" auf "enable" stehen (nur wenn dies vorhanden ist geht's).</li>
					<li>Ab jetzt kann der Receiver mit "set <device> on" aufgeweckt werden. Dauert etwas.</li>
					<li>Abschließend ist der Receiver nicht EIN sondern im Standby. Jetzt muss nochmals "set <device> on" gesetzt werden, um ihn in "play" zu bringen oder man ist geduldig (ca. 4min) dann startet er selbst.</li>
					<li>für die, die ihr Receivermodul schon gespeichert haben - ergänzt im devStateIcon offline:control_home => offline:control_home:on. Somit wird "on" durch Klick auf das Icon ausgelöst.</li>
				</ul>
			</li>
			<li><b>off</b><br />
	  			Schaltet den Receiver aus.
			</li>
			<li><b>toggel</b><br />
	  			Schaltet den Receiver aus oder ein, je nach vorherigem Status.
			</li>
			<li><b>Play</b><br />
	  			Sendet PLAY an den Receiver.
			</li>
			<li><b>Pause</b><br />
	  			Sendet PAUSE an den Receiver.
			</li>
			<li><b>volumeUp</b><br />
	  			Sendet VOLUP an den Receiver.
			</li>
			<li><b>volumeDown</b><br />
	  			Sendet VOLDOWN an den Receiver.
			</li>
			<li><b>Mute</b><br />
	  			Sendet MUTE an den Receiver.
			</li>
			<li><b>channelUp</b><br />
	  			Sendet CHUP an den Receiver.
			</li>
			<li><b>channelDown</b><br />
	  			Sendet CHDOWN an den Receiver.
			</li>
			<li><b>Rewind</b><br />
	  			Sendet REWIND an den Receiver.
			</li>
			<li><b>Forward</b><br />
	  			Sendet FORWARD an den Receiver.
			</li>
			<li><b>EPG</b><br />
	  			Sendet EPG an den Receiver.
			</li>
			<li><b>OK</b><br />
	  			Send OK to the receiver.
			</li>
			<li><b>Back</b><br />
	  			Send BACK to the receiver.
			</li>
			<li><b>Exit</b><br />
	  			Send EXIT to the receiver.
			</li>
		    <li><b>SendKey &lt;parameter&gt;</b><br />
	      		Sendet den ausgewählten Tastencode. Beispiel:
	      		<ul>
	        		<code>set &lt;name&gt; SendKey &lt;Tastencode&gt;</code>
	      		</ul>
	    	</li>	    
		    <li><b>Channel &lt;parameter&gt;</b><br />
	      		Wechselt den Sender per Kanalnummer. Die Liste der Kanalnummern entspricht den, auf dem Receiver, eingestellten Kanälen. Beispiel:
	      		<ul>
	        		<code>set &lt;name&gt; Channel 1-999</code>
	      		</ul>
	    	</li>	    
		    <li><b>ChannelName &lt;parameter&gt;</b><br />
	      		Wechselt den Sender per Sendernamen. Die Liste der Sendernamen entspricht den, auf dem Receiver, eingestellten Sendern. Beispiel:
	      		<ul>
	        		<code>set &lt;name&gt; ChannelName &lt;channelNames&gt;</code>
	      		</ul>
	    	</li>	    
	    </ul>
	</ul><br />  
  	<a name="MagentaTV_Get" id="MagentaTV_Get"></a><b>Get</b>
  	<ul>
    	ACCOUNT<br />
    	<ul>
			<li><b>DeviceList</b><br />
				Zeigt alle gefundenen Geräte als Liste.<br />
				Die Liste ist unterteilt in die Receiver, die per Upnp, wie auch per Telekom Account gefunden wurden. Auch werden alle Clients, bis zu 5 möglich, angezeigt.<br />
				Hinweis: MACWEBTV und WEBTV sind Browser Clients. Der eigene ist als 'Fhem' bezeichnet.
			</li>
			<li><b>showAccount</b><br />
	  			Zeigt den aktuell gespeicherten Nutzernamen und Password an.
			</li>
			<li><b>RefreshChannelInfo</b><br />
	  			Läd die ChannelInfo (Informationen über alle Sender) neu.
			</li>
    	</ul>
   	</ul><br />
  	<ul>
    	RECEIVER<br />
    	<ul>
			<li><b>RefreshChannelList</b><br />
				Läd die Customer und Favoriten Listen (Informationen über sichtbare Sender, wie auch die Favoriten) neu.<br />
				Anschließend bitte ein Refresh des Browsers durchführen, damit die Pulldownmenüs wieder neu geladen werden.
			</li>
    	</ul>
   	</ul><br />  	<a name="MagentaTV_Attr" id="MagentaTV_Attr"></a><b>Attributes</b>
  	<ul>
  		ACCOUNT<br />
  		<ul>
			<li><b>retryConnection</b><br />
				Default = 1<br />
				Wenn auf Grund von Netzwerkproblemen kein Login zu Telekom Account möglich ist, wird nach 5min es wieder versucht.
			</li>
			<li><b>acceptedUDNs</b><br />
				Eine Liste (durch Kommas oder Leerzeichen getrennt) von UDNs, die von der automatischen Geräteerstellung akzeptiert werden soll.<br />
				Es ist wichtig, dass uuid: ebenfalls Teil der UDN ist und enthalten sein muss.
			</li>
			<li><b>ignoreUDNs</b><br />
				Eine Liste (durch Kommas oder Leerzeichen getrennt) von UDNs, die von der automatischen Geräteerstellung ausgeschlossen werden soll.<br />
				Es ist wichtig, dass uuid: ebenfalls Teil der UDN ist und enthalten sein muss.
			</li>
			<li><b>ignoredIPs</b><br />
				Eine Liste (durch Kommas oder Leerzeichen getrennt) von IPs die ignoriert werden sollen.
			</li>
			<li><b>usedonlyIPs</b><br />
				Eine Liste (durch Kommas oder Leerzeichen getrennt) von IPs die für die Suche genutzt werden sollen.
			</li>
			<li><b>subscritionPort</b><br />
				Default ist ein zufälliger freier Port<br />
				Subscrition Port für die UPnP Services, welche der Controlpoint anlegt. 
			</li>
			<li><b>searchPort</b><br />
				Default 8008<br />
				Search Port für die UPnP Services, welche der Controlpoint anlegt.
			</li>
			<li><b>reusePort</b><br />
				Default 0<br />
				Gibt an, ob die Portwiederwendung für SSDP aktiviert werden soll, oder nicht. Kann Restart-Probleme lösen. Wenn man diese Probleme nicht hat, sollte man das Attribut nicht setzen.
			</li>
			<li><b>RescanNetworkInterval</b><br />
				Default = 0<br />
				In Minuten. Ist zum Test. Das RescanNetwork kann per Zeitintervall wiederholt werden. Dabei wird der Controlpoint gestoppt und wieder neu gestartet.
			</li>
			<li><b>expert</b><br />
				Default = 0<br />
				Aktiviert zusätzliche Funktionen für die Behandlung des Telekom Accounts und für die Diagnose:<br />
				BEACHTET: Teilweise sind Funktionen implementiert, die Einfluss auf euren Telekom Account haben. Bitte diese mit Vorsicht verwenden und erst wenn vertanden. Es kann keine Gewähr gegeben werden, was bei unbedarfter Verwendung passiert!
				<ul>
					<b>Set</b>
					<ul>
						<li><b>RefreshChannelList</b><br />
							Läd die Senderinformationen (alle) neu.
						</li>
						<li><b>RefreshDeviceList</b><br />
							Läd die Geräteliste neu.
						</li>
						<li><b>ReplaceDevice</b><br />
							Löscht die ausgewählte deviceId. Die auswählbaren deviceId's sind die, die in der DeviceList aufgeführt sind. Im Telekom Account können bis zu 5 mobile Geräte definiert werden. Wird versucht ein 6. Gerät anzumelden, wird man aufgefordert eines zu löschen. Diese Funktion stellt dies dar.<br />
							VORSICHT: Man kann auch ein Gerät löschen, ohne das es notwendig wäre! 
						</li>
						<li><b>SetPhysicalDeviceId</b><br />
							Setzt das Reading <code>physicalDeviceId</code> mit der ausgewählten physicalDeviceId. Es werden alle, in der DeviceList vorhandenen, Id's angezeigt. Die Id's werden vom Telekom Account erzeugt, somit kann eine Id nicht selbst erzeugt werden. Nutz man dazu, um die richtige physicalDeviceId wieder zuzuoednen, wenn das Reading mal gelöscht wurde.
						</li>
						<li><b>StartUpnpSearch</b><br />
							Startet die Upnp Suche nach Geräten nochmals. Startet den ControlPoint aber nicht neu.
						</li>
					</ul>
					<b>Get</b>
					<ul>
						<li><b>showData</b><br />
							Zeigt die letzten RAW Daten der Requests Login, Authenticate, Token, DTAuthenticate, HeartBit, DeviceList, SubmitDeviceInfo, ChannelInfo, ReplaceDevice, Logout.<br />
							Dient hauptsächlich der schnellen Diagnose, ohne das verbose = 5 gesetzt werden muss.
						</li>
					</ul>
				</ul>
			</li>
  		</ul>
  	</ul><br />
  	<ul>
		RECEIVER<br />
		<ul>
			<li><b>detectPlayerState</b><br />
				Default = 1<br />
				Nach dem Paring wird versucht den Zustand des Recivers (ON/OFF) zu ermitteln.
			</li>
			<li><b>Programinfo</b><br />
				Default = 1<br />
				Zeigt die aktuellen Programinfos an.
			</li>
			<li><b>PrograminfoNext</b><br />
				Default = 1<br />
				Zeigt zusätzlich die Programinfos der nächsten Sendung an.
			</li>
			<li><b>ControlButtons</b><br />
				Default = 1<br />
				Zeigt die Tasten der Fernbedienung an.
			</li>
			<li><b>renewSubscription</b><br />
				Ist eher für Tester gedacht. Ist die Zeit in s (60s...300s) für die Erneuerung der Subscription.
			</li>
			<li><b>PrograminfoReadings</b><br />
				Default = 0<br />
				Ist obsolet. Diese Anzeige ist jetzt durch die neue Programansicht ersetzt, kann aber trotzdem angezeigt werden.
			</li>
			<li><b>getPlayerStateInterval</b><br />
				Default = 0<br />
				In Minuten. Ist zum Test. Der Playerstate kann per Zeitintervall erneuert werden.
			</li>
			<li><b>SenderListType</b><br />
				Default = custom<br />
				Wählt aus, welche Senderliste benutzt werden soll.<br />
				custom - alle sichtbaren Sender<br />
				favorit - alle (nur) Favoriten
			</li>
			<li><b>expert</b><br />
				Default = 0<br />
				Aktiviert zusätzliche Funktionen für die Diagnose:<br />
				<ul>
					<b>Get</b>
					<ul>
						<li><b>showData</b><br />
							Zeigt die letzten RAW Daten der Requests CustomChannels, Favorites, SenderNameList, PlayContext, SubscriptionCallback, getPlayerState, GetTransportInfo, GetTransportSettings, pairingCheck, audioType.<br />
							Dient hauptsächlich der schnellen Diagnose, ohne das verbose = 5 gesetzt werden muss.
						</li>
					</ul>
				</ul>
			</li>
		</ul>
  	</ul><br />
  	<b>Readings</b>
  	<ul>
    	ACCOUNT<br />
		<ul>
			<li><b>CSESSIONID</b> - Cookie Sesion ID.</li>
			<li><b>CSRFSESSION</b> - Cookie CSRF Sesion ID.</li>
			<li><b>JSESSIONID</b> - Cookie J Sesion ID.</li>
			<li><b>expires_in</b> - Zeitintervall für die nächste Anmeldung am Account.</li>
			<li><b>lastRequestError</b> - Zeigt den letzten Fehler an.</li>
			<li><b>nextcallinterval</b> - Zeitintervall für Heartbit.</li>
			<li><b>physicalDeviceId</b> - physicalDeviceId als Resultat des Logins beim Telekom Account. Wird vom Telom Account zugewiesen und ist essentiell für die weitere Kommunikation mit dem Account.</li>
			<li><b>userID</b> - UserID als Resultat des Login bei der Telekom mit gültigem Nutzernamen und Password. Ist notwendig für die weitere Kommunikation per Upnp mit den Receivern.</li>
		</ul><br />
		RECEIVER<br />
	    <ul>
			<li><b>chanNo</b> - Sendernummer - wie auf dem Receiver.</li>
			<li><b>channel</b> - Sendernummer - Index, wie in der Gesamtliste aller Sender.</li>
			<li><b>channelCode</b> - Interner Channel Code.</li>
			<li><b>channelName</b> - Sendername.</li>
			<li><b>favorite</b> - Sender ist in der Liste Favoriten.</li>
			<li><b>mediaCode</b> - Interner Media Code.</li>
			<li><b>mediaType</b> - Medien Type.</li>
			<li><b>newPlayMode</b> - Zeigt den aktuellen Status des Receivers an, dieser kann wie folgt sein:</li>
			<ul TYPE=disc>
				<li>STOP</li>
				<li>PAUSE</li>
				<li>PLAY</li>
				<li>&lt;&lt;PLAY&gt;&gt;</li>
				<li>PLAY Multicast</li>
				<li>PLAY Unicast</li>
				<li>BUFFERING</li>
			</ul>
			<br />
			<li><b>pairing</b> - Aktueller Zustand des Pairings zwischen Fhem und Receiver.</li>
			<li><b>pairingCheck</b> - Rückantwort des Receiver. Benötigt um den Verifikationcode zu berechnen.</li>		
			<li><b>playBackState</b> - Ist ein weitere Status des Receivers. Die Bedeutung ist nicht ganz klar. Bei MR401 keine Änderung. Beim MR400 im Standby auf "STOP". </li>
			<ul TYPE=disc>
				<li>STOP</li>
				<li>RUN</li>
			</ul>
			<br />		
			<li><b>verificationCode</b> - Verifikationcode für die Befehle an den Receiver.</li><br />
			<b>Programinfos</b> - Ist obsolet. Diese Anzeige ist jetzt durch die neue Programansicht ersetzt, kann aber trotzdem per Attr angezeigt werden.
			<ul><br />
				<li><b>currentProgramTitle</b> - Titel des gerade laufenden Programs.</li>
				<li><b>currentProgramGenre</b> - Zusätzlicher Titel des gerade laufenden Programs.</li>
				<li><b>currentProgramStart</b> - Startzeit gerade laufenden Programs.</li>
				<li><b>currentProgramDuration</b> - Laufzeit des gerade laufenden Programs.</li>
				<li><b>currentProgramTime</b> - Startzeit und Enzeit des gerade laufenden Programs.</li>
				<li><b>currentProgramStatus</b> - Status des gerade laufenden Programs. Hier immer "PLAY".</li>
				<br />
				<li><b>nextProgramTitle</b> - Titel des nächsten Programs.</li>
				<li><b>nextProgramGenre</b> - Zusätzlicher Titel des nächsten Programs.</li>
				<li><b>nextProgramStart</b> - Startzeit des nächsten Programs.</li>
				<li><b>nextProgramDuration</b> - Laufzeit des nächsten Programs.</li>
				<li><b>nextProgramTime</b> - Startzeit und Enzeit des nächsten Programs.</li>
				<li><b>nextProgramStatus</b> - Status des nächsten Programs. Hier immer "STOP".</li>
			</ul>
			</li>
		</ul>
  	</ul><br />
</ul>

=end html_DE

=cut