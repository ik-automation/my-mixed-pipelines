#! /usr/bin/env python
# -*- coding: utf-8 -*-
"""
Test heartbeat functionality

./test_heartbeat.py --env <dev,stage,prod> --svc <api,auth,ui>
./test_heartbeat.py --env dev --svc api
"""
import argparse, logging, json, time
import urllib3

logging.basicConfig(
    format="%(asctime)s %(name)s %(levelname)s - %(message)s", level=logging.INFO
)
logging.getLogger("test-heartbeat").setLevel(logging.INFO)
logging.getLogger("urllib3").setLevel(logging.INFO)
logging.info(f"urllib3: {urllib3.__version__}")

http_200 = 200
status_ok = "Healthy"
retry = 5
timeout = 4.0
time_to_retry = 15

service_under_test = {
    "dev": {
        "auth": "https://auth.dev.singleton.link/healthz",
        "api": "https://api.dev.singleton.link/healthz",
    },
    "stage": {
        "auth": "https://auth.stage.singleton.link/healthz",
        "api": "https://api.stage.singleton.link/healthz",
    },
    "prod": {
        "auth": "https://auth.company.com/healthz",
        "api": "https://api.company.com/healthz",
    },
}


def call_service(url):
    http = urllib3.PoolManager(
        retries=urllib3.Retry(retry, redirect=4), timeout=timeout
    )
    resp = http.request("GET", url)
    return resp


def test(env, svc):
    url = service_under_test[env][svc]
    logging.info(f"{svc} -> {url}")
    for i in range(retry):
        try:
            resp = call_service(url)
            # validate status code
            assert (
                resp.status == http_200
            ), f'Incorrect response status. Expected "{http_200}", actual "{resp.status}".'
            body = json.loads(resp.data.decode("utf-8"))
            logging.info(json.dumps(body, indent=2))
            # validate status value
            assert (
                body["status"] == status_ok
            ), f"STATUS returned is incorrect. Expected \"{status_ok}\", actual \"{body['status']}\"."
            break
        except AssertionError as e:
            logging.error(f"{e} Retry {i+1} in {time_to_retry} sec...")
            time.sleep(time_to_retry)
            if i == retry - 1:
                raise Exception(f"Service {svc} in wrong state.")

    logging.info("RESULT::OK")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test Service version")
    parser.add_argument(
        "-e",
        "--env",
        required=True,
        help="Environment",
        choices=["dev", "stage", "prod"],
    )
    parser.add_argument(
        "-s", "--svc", required=True, help="Service name", choices=["api", "auth", "ui"]
    )
    args = parser.parse_args()
    logging.info(f'Validate STATUS for single service "{args.svc}"')
    test(env=args.env, svc=args.svc)
