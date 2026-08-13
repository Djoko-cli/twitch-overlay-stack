try
	set out to do shell script "/Users/Majid/Desktop/Twitch/bin/server-stop.sh 5500"
	display notification out with title "Serveur Twitch"
on error errMsg
	display notification errMsg with title "Serveur Twitch — échec"
end try
