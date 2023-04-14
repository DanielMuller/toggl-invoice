# Generate an invoice by exporting times from Toggl

No need to copy/paste, convert times manually to decimal and generate an invoice. This script creates 2 pdf files:
* The standard Toggl Report
* An invoice

## Usage
`. ./getInvoice.sh <start_date> <end_date> <invoice_number>`

* start_date: YYYY-MM-DD
* end_date: YYYY-MM-DD
* invoice_number: string

### Prerequisites
* Install `jq`
* Install `curl`
* Create the file `secrets` with all the needed values

## Disclaimer
The code has only been tested on Linux Ubuntu. MacOs might not work due to differences in the `date`command.
