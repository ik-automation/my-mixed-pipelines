#! /usr/bin/env python
# -*- coding: utf-8 -*-
"""
Test Fargate version deployed

./test_version.py --env <dev,stage,prod> --version latest --svc <api,auth,ui>
"""
import argparse, logging, time, json, time
import urllib3

logging.basicConfig(
    format="%(asctime)s %(name)s %(levelname)s - %(message)s", level=logging.INFO
)
logging.getLogger("test-version").setLevel(logging.INFO)

logging.info(f"urllib3: {urllib3.__version__}")

http_200 = 200
retry = 5
time_to_retry = 30
timeout = 4.0

service_under_test = {
    "dev": {
        "auth": "https://auth.dev.singleton.link/versionz",
        "api": "https://api.dev.singleton.link/versionz",
        "ui": "https://www.dev.singleton.link/versionz.json",
    },
    "stage": {
        "auth": "https://auth.stage.singleton.link/versionz",
        "api": "https://api.stage.singleton.link/versionz",
        "ui": "https://www.stage.singleton.link/versionz.json",
    },
    "prod": {
        "auth": "https://auth.company.com/versionz",
        "api": "https://api.company.com/versionz",
        "ui": "https://www.company.com/versionz.json",
    },
}


def call_service(url):
    http = urllib3.PoolManager(timeout=timeout)
    resp = http.request("GET", url)
    return resp


def test(env, svc, version):
    url = service_under_test[env][svc]
    logging.info(f"{svc} -> {url}")
    for i in range(retry):
        try:
            resp = call_service(url)
            # validate status code
            assert (
                resp.status == http_200
            ), f'Incorrect response status. Expected "{http_200}", actual "{resp.status}".'
            parsed = json.loads(resp.data.decode("utf-8"))
            logging.info(json.dumps(parsed, indent=2))
            # validate environment
            assert (
                parsed["environment"] == env
            ), f"ENV returned is incorrect. Expected \"{env}\", actual \"{parsed['environment']}\"."
            # validate version
            if "latest" not in version:
                assert (
                    parsed["version"] == version
                ), f"VERSION returned is incorrect. Expected \"{version}\", actual \"{parsed['version']}\"."
            break
        except AssertionError as e:
            logging.error(f"{e} Retry {i+1} in {time_to_retry} sec...")
            time.sleep(time_to_retry)
            if i == retry - 1:
                raise Exception(f"Service {svc} in wrong state.")

    logging.info("RESULT::OK")


if __name__ == "__main__":
    logging.info("Test deployed version")
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
    parser.add_argument("-v", "--version", required=True, help="Service Version")
    args = parser.parse_args()
    test(env=args.env, svc=args.svc, version=args.version)
