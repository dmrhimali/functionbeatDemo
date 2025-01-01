#!/usr/bin/env bash
./functionbeat update cloudwatch || ./functionbeat deploy cloudwatch || echo "complete deploying cloudwatch lambda"

#sucess=false
#
#output=$(./functionbeat update cloudwatch)
#
#if echo $output | grep -q "ValidationError: No updates are to be performed"; then
#    echo "ValidationError: No updates are to be performed"
#    sucess=true
#    echo "cloudwatch functionbeat already up-to-date"
#elif echo $output | grep -q "ValidationError: Stack [fnb-cloudwatch-stack] does not exist"; then
#    echo "ValidationError: Stack [fnb-cloudwatch-stack] does not exist"
#    output = $(./functionbeat deploy cloudwatch)
#    if echo $output | grep -q "deploy successful"; then
#        sucess=true
#        output "cloudwatch functionbeat deployed"
#    fi
#else
#     echo "something went wrong: ", $output
#fi
#
#echo "success:" $sucess