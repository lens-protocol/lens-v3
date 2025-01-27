#!/bin/bash

# Get all events from local node
cast logs --rpc-url http://localhost:8011 > events.txt
