#!/bin/bash

echo "Monitoring NoQCNoLife logs..."
echo "Please click on the menu bar icon to trigger detection"
echo "Press Ctrl+C to stop"
echo "================================================"

log stream --process NoQCNoLife 2>&1 | grep "NoQCNoLife"