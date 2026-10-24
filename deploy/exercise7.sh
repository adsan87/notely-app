#!/usr/bin/env bash
# Exercise 7 - the scaling envelope of both services, an uptime check through the page, two alerts
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
gcloud services enable monitoring.googleapis.com

# 1. Scale out between 1 and 3 instances, for the page and for the API
for SERVICE in notely-web notely-api; do
  gcloud run services update "${SERVICE}" --region "${REGION}" --min-instances=1 --max-instances=3
done

# 2. Create the two e-mail channels in the console (Monitoring > Alerting > Edit notification channels),
#    then paste their names:
IT_CH="projects/${PROJECT_ID}/notificationChannels/REPLACE_ME"
FOUNDER_CH="projects/${PROJECT_ID}/notificationChannels/REPLACE_ME"

# 3. The uptime check calls the page's /health, which the page forwards to the API (which runs SELECT 1):
#    one probe covers what a user goes through. The API itself is not reachable from the internet.
WEB_HOST=$(gcloud run services describe notely-web --region "${REGION}" --format='value(status.url)' | sed 's|https://||')
gcloud monitoring uptime create "Notely /health" --resource-type=uptime-url \
  --resource-labels="host=${WEB_HOST},project_id=${PROJECT_ID}" --protocol=https --port=443 --path=/health --period=1 --timeout=10
UPTIME_ID=$(gcloud monitoring uptime list-configs --format='value(name)' --filter='displayName="Notely /health"' | awk -F/ '{print $NF}')

# 4. Two alerting policies: the app is down (IT and the founder), the API answers 5xx (IT)
for f in down errors; do
  sed -e "s|IT_CHANNEL|${IT_CH}|g" -e "s|FOUNDER_CHANNEL|${FOUNDER_CH}|g" -e "s|UPTIME_CHECK_ID|${UPTIME_ID}|g" "$(dirname "$0")/alerts/${f}.json" > "/tmp/${f}.json"
  gcloud monitoring policies create --policy-from-file="/tmp/${f}.json"
done

# 5. Prove the error alert: eight deliberate errors, through the page (the only way in)
for i in $(seq 8); do curl -s -o /dev/null -w '%{http_code}\n' "https://${WEB_HOST}/api/boom"; done
