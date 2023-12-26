#!/bin/bash
#Script for automatic data deletion, based on local node's available space left.
#When the local volume gets 90% full, API request is sent to delete the oldest indice on the elasticsearch cluster.
#Default cooldown between checking storage size is 30 minutes.

sleep 60

while true; do
#parsing the space left, in %
df>/var/indexcontroller/df_input.txt
df_input_current_size=$(awk '/\/dev\/mapper\/ubuntu--vg-ubuntu--lv/ { print $5-0 }' /var/indexcontroller/df_input.txt)

    if [ $df_input_current_size -ge 90 ]; then
    echo "Size is critical, executing flushing instructions..."
    echo "Getting the right indice..."
      #requesting indices list
      curl -k -s -u USERNAME:PASSWORD -XGET https://127.0.0.1:9200/_cat/indices/.ds-filebeat*?\&s=index > /var/indexcontroller/requested_indice_list.txt
      oldest_indice=$(awk 'NR==1 { print $3 }' /var/indexcontroller/requested_indice_list.txt)

      #optional paranoid data validation to make sure funny stuff wont get at DELETE https://127.0.0.1:9200/<funnystuff>" request
      if [[ $oldest_indice == ".ds-filebeat-8.10.0-"* ]]; then
      echo "Validating indice: OK"
      echo "Sending delete request..."
      #deleting
      http_response_code=$(curl -k -u USERNAME:PASSWORD -o /dev/null -s -w "%{http_code}\n" -X DELETE https://127.0.0.1:9200/$oldest_indice)

        if [ $http_response_code -ne 200 ]; then
          echo "$(date +%e.%m.%Y," "%R), Unexpected http return code: $httpCode." >> /var/log/indexcontroller/index_controller.log
        else
          echo "$(date +%e.%m.%Y," "%R), Deleted $oldest_indice." >> /var/log/indexcontroller/index_controller.log
        fi
        echo "Sleeping for 60 secs to make sure OS performed the changes..."; echo ""
        sleep 60 #optional time window for host node to free the disk space
      fi
    else
     echo "Storage state is OK. Waiting for another check for 3 secs."
     sleep 1800 #30 mins
    fi

done
