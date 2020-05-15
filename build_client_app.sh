#!/bin/bash

(cd client-app && npm i && npx ember build --environment=${1:-production})

rm assets/javascript/*
rm assets/stylesheets/client-app.css
rm assets/stylesheets/vendor.css

cp client-app/dist/assets/client-app.js assets/javascript/client-app.js
cp client-app/dist/assets/vendor.js assets/javascript/vendor.js
cp client-app/dist/assets/client-app.css assets/stylesheets/client-app.css
cp client-app/dist/assets/vendor.css assets/stylesheets/vendor.css
