#!/bin/bash

usage () {
    echo >&2 "Usage: ./getInvoice.sh YYYY-MM-DD YYYY-MM-DD InvoiceNumber"
    echo >&2 ""
}

if [ "$#" -ne 3 ]; then
    echo >&2 "Start, End and Invoice Number required, $# argument(s) provided"
    echo >&2 ""
    usage
    return 1 2>/dev/null
    exit 1
fi

if [[ ! $1 =~ ^2[0-9]{3}-[0-9]{2}-[0-9]{2}$ ]] || [[ ! $2 =~ ^2[0-9]{3}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo >&2 "Invalid date format, expected YYYY-MM-DD"
    echo >&2 ""
    return 1 2>/dev/null
    exit 1
fi

if ! date -d "$1" &> /dev/null || ! date -d "$2" &> /dev/null; then
    echo >&2 "Invalid date"
    echo >&2 ""
    return 1 2>/dev/null
    exit 1
fi

START_DATE=$1
END_DATE=$2
INVOICE_NUMBER=$3

mkdir -p tmp
mkdir -p outputs

source secrets

TOGGL_AUTH=$(echo -n "${TOGGL_TOKEN}:api_token" | base64)

curl -o tmp/track.csv -s "https://api.track.toggl.com/reports/api/v3/workspace/${TOGGL_WORKSPACE}/summary/time_entries.csv" \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic ${TOGGL_AUTH}" \
  -d '{"duration_format":"decimal","start_date":"'${START_DATE}'","end_date":"'${END_DATE}'","date_format":"YYYY-MM-DD","grouping":"clients","sub_grouping":"projects","hide_amounts":false,"hide_rates":true,"order_by":"duration","order_dir":"desc","user_ids":['${TOGGL_USER}']}'\
  --compressed

DUE_DATE=$(date -d "+14 days" +"%e %b %Y")
PERIOD_FROM=$(date -d "${START_DATE}" +"%e")
PERIOD_TO=$(date -d "${END_DATE}" +"%e %b %Y")
PERIOD="${PERIOD_FROM} - ${PERIOD_TO}"

INVOICE_PAYLOAD='{
    "from": "'${FROM}'",
    "to_title": "TO",
    "from_title": "FROM",
    "due_date": "'${DUE_DATE}'",
    "to": "'${TO}'",
    "number": "'${INVOICE_NUMBER}'",
    "custom_fields": [
        {
            "name": "Billing Period",
            "value": "'${PERIOD}'"
        },
        {
            "name": "'${METHOD_TITLE}'",
            "value": "'${METHOD_ADDRESS}'"
        }
    ],
    "items": [],
    "fields": {
        "tax": "%",
        "discounts": false,
        "shipping": false
    },
    "tax": 0
}'

while IFS="," read -r client project duration extra;
do
  ROW_DURATION=$(printf "%.2f" $duration)
  ROW_NAME="${client} - ${project}"
  RATE=$(printf "%.2f" $RATE)

  INVOICE_PAYLOAD=$(jq \
  --arg name "${ROW_NAME}" \
  --arg duration $ROW_DURATION \
  --arg rate $RATE \
  '.items += [{
    "name": $ARGS.named.name,
    "quantity": $ARGS.named.duration,
    "unit_cost": $ARGS.named.rate
  }]' <<< "$INVOICE_PAYLOAD")
done < <(tail -n +2 tmp/track.csv)

echo $INVOICE_PAYLOAD > tmp/payload.json
INVOICE="invoice_${INVOICE_NUMBER}.pdf"

curl -o outputs/$INVOICE -s https://invoice-generator.com \
  -H "Content-Type: application/json" \
  -d @tmp/payload.json

REPORT="Toggl_Track_summary_report_${START_DATE}_${END_DATE}.pdf"

curl -o outputs/$REPORT -s https://api.track.toggl.com/reports/api/v3/workspace/${TOGGL_WORKSPACE}/summary/time_entries.pdf \
  -H "authorization: Basic ${TOGGL_AUTH}" \
  --data-raw '{"collapse":true,"grouping":"projects","sub_grouping":"time_entries","end_date":"'${END_DATE}'","start_date":"'${START_DATE}'","user_ids":['${TOGGL_USER}'],"audit":{"show_empty_groups":false,"show_tracked_groups":true,"group_filter":{}},"date_format":"DD-MM-YYYY","duration_format":"improved","hide_amounts":false,"hide_rates":true,"order_by":"title","order_dir":"asc"}' \
  --compressed

rm -rf tmp/