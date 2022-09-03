#!/bin/bash

source "$(dirname $0)/utils.sh"

kubespray-run bash /inventory/contrib/offline/generate_list.sh
