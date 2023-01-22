#! /usr/bin/env python
# -*- coding: utf-8 -*-
"""
Test Redirects functionality

urllib: https://urllib3.readthedocs.io/en/stable/user-guide.html

TODO:
- production endpoints

curl -I https://www.stage.singleton.link/blog/25-flights-and-zero-emissions-how-electric-planes-will-change-air-travel/
curl -I https://www.stage.singleton.link/blog
curl -I https://www.stage.singleton.link/blog/

curl -I https://www.dev.singleton.link/blog/25-flights-and-zero-emissions-how-electric-planes-will-change-air-travel/
curl -I https://www.dev.singleton.link/blog
curl -I https://www.dev.singleton.link/blog/

./test_redirect.py --env <dev,stage,prod>
./test_heartbeat.py --env dev
"""
import argparse, logging
import urllib3

logging.basicConfig(
    format="%(asctime)s %(name)s %(levelname)s - %(message)s", level=logging.INFO
)
logging.getLogger("test-heartbeat").setLevel(logging.INFO)
logging.getLogger("urllib3").setLevel(logging.INFO)
logging.debug(f"urllib3: {urllib3.__version__}")

http_200 = 200
retry = 5

url_under_test = {
    "dev": {
        "http://www.dev.singleton.link": "https://www.dev.singleton.link:443/",
        "http://dev.singleton.link": "https://www.dev.singleton.link:443/",
        "https://dev.singleton.link": "https://www.dev.singleton.link:443/",
        "https://www.dev.singleton.link/blog": "https://www.dev.singleton.link:443/money-smarts/",
        "https://www.dev.singleton.link/blog/": "https://www.dev.singleton.link:443/money-smarts/",
        "https://www.dev.singleton.link:443/blog/25-flights-and-zero-emissions-how-electric-planes-will-change-air-travel/": "https://www.dev.singleton.link:443/money-smarts/25-flights-and-zero-emissions-how-electric-planes-will-change-air-travel/",
        "http://auth.dev.singleton.link/readyz": "https://auth.dev.singleton.link:443/readyz",
        "http://api.dev.singleton.link/readyz": "https://api.dev.singleton.link:443/readyz",
    },
    "stage": {
        "http://www.stage.singleton.link": "https://www.stage.singleton.link:443/",
        "http://stage.singleton.link": "https://www.stage.singleton.link:443/",
        "https://stage.singleton.link": "https://www.stage.singleton.link:443/",
        "https://www.stage.singleton.link/blog": "https://www.stage.singleton.link:443/money-smarts/",
        "https://www.stage.singleton.link/blog/": "https://www.stage.singleton.link:443/money-smarts/",
        "https://www.stage.singleton.link:443/blog/25-flights-and-zero-emissions-how-electric-planes-will-change-air-travel/": "https://www.stage.singleton.link:443/money-smarts/25-flights-and-zero-emissions-how-electric-planes-will-change-air-travel/",
        "http://auth.stage.singleton.link/readyz": "https://auth.stage.singleton.link:443/readyz",
        "http://api.stage.singleton.link/readyz": "https://api.stage.singleton.link:443/readyz",
    },
}


def call_service(url):
    http = urllib3.PoolManager(retries=urllib3.Retry(retry, redirect=4), timeout=4.0)
    resp = http.request("GET", url)
    return resp


def test(env):
    for url, expected in url_under_test[env].items():
        logging.info(f"GET Request: {url}")
        try:
            resp = call_service(url)
            # validate status code
            assert (
                resp.status == http_200
            ), f'Incorrect response status. Expected "{http_200}", actual "{resp.status}".'
            # validate redirect
            assert (
                resp.geturl() == expected
            ), f'Incorrect redirect. Expected "{expected}", actual "{resp.geturl()}".'
        except AssertionError as e:
            logging.error(f"{e}")
            logging.error(f"RESULT::FAIL")
            raise Exception(f"URL {url} does not redirect to {expected}.")
    logging.info(f"RESULT::OK")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test Redirects")
    parser.add_argument(
        "-e",
        "--env",
        required=True,
        help="Environment",
        choices=["dev", "stage", "prod"],
    )
    args = parser.parse_args()
    logging.info(f"Validate REDIRECTS for multiple services. ENV: {args.env}")
    test(env=args.env)
