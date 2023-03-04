#!/bin/bash

(cd client-app && yarn && yarn ember build --environment=${1:-production})

rm -f assets/javascript/*
rm -f assets/stylesheets/client-app.css
rm -f assets/stylesheets/vendor.css

cp client-app/dist/assets/*.js assets/javascript/
cp client-app/dist/assets/*.css assets/stylesheets/
