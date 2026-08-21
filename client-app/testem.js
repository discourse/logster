"use strict";

const browser = process.env.TESTEM_BROWSER || "Chrome";

module.exports = {
  test_page: "tests/index.html?hidepassed",
  disable_watching: true,
  launch_in_ci: [browser],
  launch_in_dev: [browser],
  browser_start_timeout: 120,
  browser_args: {
    [browser]: {
      ci: [
        process.env.CI ? "--no-sandbox" : null,
        "--headless",
        "--disable-dev-shm-usage",
        "--disable-software-rasterizer",
        "--mute-audio",
        "--remote-debugging-port=0",
        "--window-size=1440,900",
      ].filter(Boolean),
    },
  },
};
