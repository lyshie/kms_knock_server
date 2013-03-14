#!/bin/sh

socat -d TCP4-LISTEN:1688,fork TCP4:kms-server:1688
