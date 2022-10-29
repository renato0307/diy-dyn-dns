#!/bin/bash
curl -X POST $DIY_DYN_DNS_UPDATE_ENDPOINT \
     -H "Authorization: $DIY_DYN_DNS_UPDATE_API_KEY" \
     -I --ipv4 \
