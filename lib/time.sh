#!/usr/bin/env bash

# Vertex - Time Utilities

time_now() {
    date "+%Y-%m-%d %H:%M:%S"
}

time_iso8601() {
    date -u "+%Y-%m-%dT%H:%M:%SZ"
}

time_epoch() {
    date "+%s"
}
