# MagentaTV - Fhem
## MagentaTV - Fhem Integration

MagentaTV findet automatisch alle MagentaTV Receiver, kann diese steuern und zeigt Programminformationen an.

Getestet mit MR401, MR400

Es wird für die Darstellung der Programminformationen ein ständig aktiver Telekom Account benötigt. Dieser Client wird als 'Fhem' (Browser Type MACWEBTV) in der DeviceList angezeigt. Es sind nur bis zu 5 Clients möglich. Damit könnte es zu Schwierigkeiten kommen, sofern die Anzahl an Clients schon ausgeschöpft ist.

### update

`update add https://raw.githubusercontent.com/RP-Develop/MagentaTV/main/controls_MagentaTV.txt`

## Voraussetzung: 

Folgende Libraries sind notwendig für dieses Modul:

- Digest::MD5
- HTML::Entities
- JSON
- HttpUtils
- Blocking
- UPnP::ControlPoint
- Date::Parse
- Encode

## 78_MagentaTV.pm

`define <name> MagentaTV Benutzername Password`

Beispiel: `define MagentaTV MagentaTV user@t-online.de password`

Nach ca. 2 Minuten sollten alle Receiver gefunden und unter "MagentaTV" gelistet sein.

Die Hilfe zu weiteren Funktionen, ist nach Installation in der Commandref zu finden. 