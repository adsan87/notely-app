#!/usr/bin/env bash
# Exercise 7 - the scaling envelope, an uptime check, two alerts
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
gcloud services enable monitoring.googleapis.com
gcloud run services update notely-api --region "${REGION}" --min-instances=1 --max-instances=10
# Create the two e-mail channels in the console (Monitoring > Alerting > Edit notification channels), then paste their names:
IT_CH="projects/${PROJECT_ID}/notificationChannels/REPLACE_ME"
FOUNDER_CH="projects/${PROJECT_ID}/notificationChannels/REPLACE_ME"
API_HOST=$(gcloud run services describe notely-api --region "${REGION}" --format='value(status.url)' | sed 's|https://||')
gcloud monitoring uptime create "Notely /health" --resource-type=uptime-url \
  --resource-labels="host=${API_HOST},project_id=${PROJECT_ID}" --protocol=https --port=443 --path=/health --period=1 --timeout=10
UPTIME_ID=$(gcloud monitoring uptime list-configs --format='value(name)' --filter='displayName="Notely /health"' | awk -F/ '{print $NF}')
# [UNVERIFIED] flag name: check `gcloud monitoring policies create --help`.
for f in down errors; do
  sed -e "s|IT_CHANNEL|${IT_CH}|g" -e "s|FOUNDER_CHANNEL|${FOUNDER_CH}|g" -e "s|UPTIME_CHECK_ID|${UPTIME_ID}|g" "$(dirname "$0")/alerts/${f}.json" > "/tmp/${f}.json"
  gcloud monitoring policies create --policy-from-file="/tmp/${f}.json"
done
for i in $(seq 8); do curl -s -o /dev/null -w '%{http_code}\n' "https://${API_HOST}/api/boom"; done
