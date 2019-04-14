# DNG-ValveItems

Under linux it could be necessary to convert the csgo_english.txt from utf16-le to utf-8, otherwise you'll see no name.
Example to convert the file: iconv -f utf-16le -t utf-8 csgo_english.txt > csgo_english_test.txt
Usage with LGSM:
 - Open `~/lgsm/config-lgsm/csgoserver/csgoserver.cfg`
 - Add this line `iconv -f utf-16le -t utf-8 ~/serverfiles/csgo/resource/csgo_english.txt > ~/serverfiles/csgo/resource/csgo_english_utf8.txt`

Usage with Easy-WI:
 - Open stuff/methods/class_app.php
 - Search this line: `if ($this->appServerDetails['protectionModeStarted'] == 'Y') {`
 - Add above this line: `$script .= 'iconv -f utf-16le -t utf-8 ' . $serverDir . 'csgo/csgo/resource/csgo_english.txt > ' . $serverDir . 'csgo/csgo/resource/csgo_english_utf8.txt' . "\n";`